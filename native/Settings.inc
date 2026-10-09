- (NSString *)shortcutTitle {
    NSMutableString *title=[NSMutableString string];
    if(self.shortcutModifiers&controlKey)[title appendString:@"⌃"];
    if(self.shortcutModifiers&optionKey)[title appendString:@"⌥"];
    if(self.shortcutModifiers&shiftKey)[title appendString:@"⇧"];
    if(self.shortcutModifiers&cmdKey)[title appendString:@"⌘"];
    [title appendString:self.shortcutName?:@"Space"];return title;
}
- (BOOL)registerShortcut:(UInt16)code modifiers:(UInt32)mods name:(NSString *)name persist:(BOOL)persist {
    UInt16 previousCode=self.shortcutCode;UInt32 previousMods=self.shortcutModifiers;
    if(self.hotkey){UnregisterEventHotKey(self.hotkey);self.hotkey=NULL;}
    EventHotKeyID ident={'LPD2',1};
    OSStatus error=RegisterEventHotKey(code,mods,ident,GetApplicationEventTarget(),0,&_hotkey);
    if(error!=noErr){
        if(!self.recordingShortcut)RegisterEventHotKey(previousCode,previousMods,ident,GetApplicationEventTarget(),0,&_hotkey);
        self.settingsStatus.stringValue=@"这个快捷键无法注册，请换一个组合。";
        NSLog(@"Launchpad2 shortcut registration failed: %d",(int)error);return NO;
    }
    self.shortcutCode=code;self.shortcutModifiers=mods;self.shortcutName=name;
    if(persist){NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
        [defaults setInteger:code forKey:@"ShortcutKeyCode"];[defaults setInteger:mods forKey:@"ShortcutModifiers"];[defaults setObject:name forKey:@"ShortcutName"];
    }
    self.shortcutButton.title=[self shortcutTitle];return YES;
}
- (void)recordShortcut:(id)sender {
    if(self.recordingShortcut){[self cancelShortcutRecording];return;}
    self.recordingShortcut=YES;
    if(self.hotkey){UnregisterEventHotKey(self.hotkey);self.hotkey=NULL;}
    self.shortcutButton.title=@"按下新的快捷键（Esc 取消）";
    self.settingsStatus.stringValue=@"使用 Command / Control / Option 的组合，或 F1–F20 功能键。";
    [self.settingsWindow makeFirstResponder:self.shortcutButton];
}
- (void)cancelShortcutRecording {
    if(!self.recordingShortcut)return;
    self.recordingShortcut=NO;
    [self registerShortcut:self.shortcutCode modifiers:self.shortcutModifiers name:self.shortcutName persist:NO];
    [self updateGestureStatus];
}
- (NSEvent *)recordShortcutEvent:(NSEvent *)event {return [self recordShortcutEvent:event persist:YES];}
- (NSEvent *)recordShortcutEvent:(NSEvent *)event persist:(BOOL)persist {
    if(event.keyCode==53){[self cancelShortcutRecording];return nil;}
    NSEventModifierFlags flags=event.modifierFlags;
    UInt32 mods=0;if(flags&NSEventModifierFlagCommand)mods|=cmdKey;
    if(flags&NSEventModifierFlagControl)mods|=controlKey;
    if(flags&NSEventModifierFlagOption)mods|=optionKey;
    if(flags&NSEventModifierFlagShift)mods|=shiftKey;
    NSString *name=event.charactersIgnoringModifiers.uppercaseString;
    unichar key=name.length?[name characterAtIndex:0]:0;
    BOOL function=key>=NSF1FunctionKey&&key<=NSF20FunctionKey;
    if(!(mods&(cmdKey|controlKey|optionKey))&&!function){self.settingsStatus.stringValue=@"请增加 Command、Control 或 Option，避免占用普通输入按键。";return nil;}
    switch(event.keyCode){
        case kVK_Space:name=@"Space";break;case kVK_Return:name=@"Return";break;
        case kVK_Tab:name=@"Tab";break;case kVK_Delete:name=@"Delete";break;
        case kVK_LeftArrow:name=@"←";break;case kVK_RightArrow:name=@"→";break;
        case kVK_UpArrow:name=@"↑";break;case kVK_DownArrow:name=@"↓";break;
        default:if(function)name=[NSString stringWithFormat:@"F%u",key-NSF1FunctionKey+1];break;
    }
    if(!name.length){self.settingsStatus.stringValue=@"无法识别这个按键，请选择其他组合。";return nil;}
    if([self registerShortcut:event.keyCode modifiers:mods name:name persist:persist]){
        self.recordingShortcut=NO;[self updateGestureStatus];
    }
    return nil;
}
- (void)defaultShortcut:(id)sender {
    self.recordingShortcut=NO;
    if([self registerShortcut:kVK_Space modifiers:controlKey|optionKey name:@"Space" persist:YES])[self updateGestureStatus];
}
- (NSTextField *)settingsLabel:(NSString *)text rect:(NSRect)rect font:(CGFloat)font {
    NSTextField *label=[NSTextField labelWithString:text];label.frame=rect;label.font=[NSFont systemFontOfSize:font];
    label.maximumNumberOfLines=0;label.lineBreakMode=NSLineBreakByWordWrapping;
    [self.settingsWindow.contentView addSubview:label];return label;
}
- (void)settings {
    [self dismiss];[self.window orderOut:nil];self.closing=NO;
    if(!self.settingsWindow){
        self.settingsWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,560,350)
            styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
        self.settingsWindow.title=@"Launchpad2 设置";self.settingsWindow.releasedWhenClosed=NO;self.settingsWindow.delegate=self;
        LPFolderSurface *content=[[LPFolderSurface alloc]initWithFrame:NSMakeRect(0,0,560,350)];self.settingsWindow.contentView=content;
        [self settingsLabel:@"打开 / 收起快捷键" rect:NSMakeRect(24,24,190,24) font:14];
        self.shortcutButton=[NSButton buttonWithTitle:[self shortcutTitle]target:self action:@selector(recordShortcut:)];
        self.shortcutButton.frame=NSMakeRect(230,18,300,32);[content addSubview:self.shortcutButton];
        [self settingsLabel:@"点击右侧按钮，再按下新的组合键；Esc 取消。" rect:NSMakeRect(24,64,380,32) font:12];
        NSButton *reset=[NSButton buttonWithTitle:@"恢复默认" target:self action:@selector(defaultShortcut:)];reset.frame=NSMakeRect(420,58,110,28);[content addSubview:reset];
        self.gestureButton=[NSButton checkboxWithTitle:@"五指收拢打开、展开关闭（实验功能）"target:self action:@selector(gestureChanged:)];
        self.gestureButton.frame=NSMakeRect(24,112,510,26);self.gestureButton.state=lp_gesture_enabled()?NSControlStateValueOn:NSControlStateValueOff;[content addSubview:self.gestureButton];
        [self settingsLabel:@"触发幅度" rect:NSMakeRect(24,154,100,24) font:13];
        [self settingsLabel:@"小" rect:NSMakeRect(170,157,22,20) font:12];
        self.gestureSlider=[NSSlider sliderWithValue:[NSUserDefaults.standardUserDefaults objectForKey:@"PinchThreshold"]?[NSUserDefaults.standardUserDefaults floatForKey:@"PinchThreshold"]:.24
            minValue:.15 maxValue:.40 target:self action:@selector(gestureThresholdChanged:)];
        self.gestureSlider.frame=NSMakeRect(200,150,290,28);self.gestureSlider.continuous=YES;[content addSubview:self.gestureSlider];
        [self settingsLabel:@"大" rect:NSMakeRect(505,157,22,20) font:12];
        self.settingsStatus=[self settingsLabel:@""rect:NSMakeRect(24,198,512,40) font:12];
        NSTextField *notice=[self settingsLabel:@"五指手势使用非公开的系统触控接口，系统更新后可能不可用。若和系统手势同时触发，请关闭相冲突的系统手势。普通快捷键不依赖此功能。"
            rect:NSMakeRect(24,254,512,72) font:12];notice.textColor=NSColor.secondaryLabelColor;
        [self.settingsWindow center];
    }
    self.shortcutButton.title=[self shortcutTitle];[self updateGestureStatus];
    [NSApp activateIgnoringOtherApps:YES];[self.settingsWindow makeKeyAndOrderFront:nil];
    [self.settingsTimer invalidate];__weak LPController *weak=self;
    self.settingsTimer=[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){if(!weak.recordingShortcut)[weak updateGestureStatus];}];
}
- (void)updateGestureStatus {
    self.gestureButton.state=lp_gesture_enabled()?NSControlStateValueOn:NSControlStateValueOff;
    self.gestureSlider.enabled=lp_gesture_enabled();
    NSString *status=@(lp_gesture_status());
    self.settingsStatus.stringValue=lp_gesture_enabled()?[NSString stringWithFormat:@"%@ · 当前触点 %d\n幅度越小越容易触发；每次动作后抬起手指。",status,lp_gesture_contacts()]:status;
}
- (void)gestureChanged:(NSButton *)sender {
    BOOL enable=sender.state==NSControlStateValueOn;
    lp_gesture_threshold(self.gestureSlider.floatValue);
    if(enable)enable=lp_gesture_start(GestureAction);else lp_gesture_stop();
    [NSUserDefaults.standardUserDefaults setBool:enable forKey:@"FiveFingerGesture"];
    [self updateGestureStatus];
}
- (void)gestureThresholdChanged:(NSSlider *)sender {
    lp_gesture_threshold(sender.floatValue);
    [NSUserDefaults.standardUserDefaults setFloat:sender.floatValue forKey:@"PinchThreshold"];
}
- (void)windowWillClose:(NSNotification *)notification {
    if(notification.object==self.settingsWindow){[self cancelShortcutRecording];[self.settingsTimer invalidate];self.settingsTimer=nil;}
}
