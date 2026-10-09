@interface LPSearchIcon:NSImageView @end
@implementation LPSearchIcon
- (NSView *)hitTest:(NSPoint)point{return nil;}
@end
@interface LPSearchBox:NSView
@property(nonatomic,strong) NSTextField *input;
@property(nonatomic,strong) NSImageView *icon;
@property(nonatomic,strong) NSButton *clearButton;
@end
@implementation LPSearchBox
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])){
        self.wantsLayer=YES;self.layer.cornerRadius=8;
        self.layer.backgroundColor=[NSColor colorWithWhite:1 alpha:.12].CGColor;
        self.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        self.icon=[[LPSearchIcon alloc]initWithFrame:NSZeroRect];
        self.icon.image=[NSImage imageWithSystemSymbolName:@"magnifyingglass" accessibilityDescription:@"搜索"];
        self.icon.contentTintColor=[NSColor colorWithWhite:1 alpha:.7];[self addSubview:self.icon];
        self.input=[[NSTextField alloc]initWithFrame:NSZeroRect];
        self.input.font=[NSFont systemFontOfSize:13];self.input.bordered=NO;self.input.bezeled=NO;
        self.input.drawsBackground=NO;self.input.textColor=NSColor.whiteColor;
        self.input.focusRingType=NSFocusRingTypeNone;self.input.cell.usesSingleLineMode=YES;
        self.input.cell.scrollable=YES;
        self.input.placeholderAttributedString=[[NSAttributedString alloc]initWithString:@"搜索"
            attributes:@{NSFontAttributeName:self.input.font,NSForegroundColorAttributeName:[NSColor colorWithWhite:1 alpha:.65]}];
        [self addSubview:self.input];
        self.clearButton=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"xmark.circle.fill" accessibilityDescription:@"清空搜索"]target:nil action:nil];
        self.clearButton.bordered=NO;self.clearButton.hidden=YES;[self addSubview:self.clearButton];
        [self layout];
    }return self;
}
- (BOOL)isFlipped{return YES;}
- (void)layout {
    [super layout];
    CGFloat height=ceil(self.input.intrinsicContentSize.height);
    height=MIN(MAX(height,16),self.bounds.size.height-8);
    self.icon.frame=NSMakeRect(10,(self.bounds.size.height-16)/2,16,16);
    self.input.frame=NSMakeRect(36,floor((self.bounds.size.height-height)/2),MAX(1,self.bounds.size.width-68),height);
    self.clearButton.frame=NSMakeRect(self.bounds.size.width-26,(self.bounds.size.height-18)/2,18,18);
    self.clearButton.hidden=self.input.stringValue.length==0;
}
- (void)mouseDown:(NSEvent *)event {[self.window makeFirstResponder:self.input];}
@end
