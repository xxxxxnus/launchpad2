- (void)setupScene {
    self.rootIcons=[NSMutableDictionary dictionary];self.folderIcons=[NSMutableDictionary dictionary];
    self.rootViewport=[CALayer layer];self.rootViewport.geometryFlipped=YES;self.rootViewport.masksToBounds=YES;
    self.rootStrip=[CALayer layer];self.rootStrip.anchorPoint=CGPointZero;self.rootStrip.geometryFlipped=YES;
    [self.rootViewport addSublayer:self.rootStrip];[self.layer addSublayer:self.rootViewport];
    self.rootDots=[CALayer layer];[self.layer addSublayer:self.rootDots];
    self.folderSurface=[[LPFolderSurface alloc]initWithFrame:NSZeroRect];self.folderSurface.wantsLayer=YES;
    self.folderSurface.hidden=YES;[self addSubview:self.folderSurface];
    CALayer *panel=self.folderSurface.layer;panel.cornerRadius=28;panel.backgroundColor=[NSColor colorWithWhite:.26 alpha:.77].CGColor;
    panel.borderColor=[NSColor colorWithWhite:1 alpha:.16].CGColor;panel.borderWidth=1;
    panel.shadowColor=NSColor.blackColor.CGColor;panel.shadowOpacity=.18;panel.shadowRadius=24;panel.shadowOffset=CGSizeMake(0,8);
    self.folderViewport=[CALayer layer];self.folderViewport.geometryFlipped=YES;self.folderViewport.masksToBounds=YES;
    self.folderStrip=[CALayer layer];self.folderStrip.anchorPoint=CGPointZero;self.folderStrip.geometryFlipped=YES;
    [self.folderViewport addSublayer:self.folderStrip];[panel addSublayer:self.folderViewport];
    self.folderDots=[CALayer layer];[panel addSublayer:self.folderDots];
    self.hoverRing=[CAShapeLayer layer];self.hoverRing.fillColor=[NSColor colorWithWhite:1 alpha:.14].CGColor;
    self.hoverRing.strokeColor=[NSColor colorWithWhite:1 alpha:.45].CGColor;self.hoverRing.lineWidth=1.5;
    self.hoverRing.opacity=0;[self.layer addSublayer:self.hoverRing];
    self.ghostLayer=[CALayer layer];self.ghostLayer.opacity=0;[self.layer addSublayer:self.ghostLayer];
    self.sceneReady=YES;
}
- (void)setNeedsDisplay:(BOOL)flag {
    if(flag&&self.sceneReady)[self syncScene:self.animateLayout];
    [super setNeedsDisplay:flag];
}
- (CGImageRef)texture:(NSDictionary *)item size:(NSSize)size selected:(BOOL)selected CF_RETURNS_RETAINED {
    CGFloat scale=self.window.backingScaleFactor?:2;
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL
        pixelsWide:MAX(1,ceil(size.width*scale)) pixelsHigh:MAX(1,ceil(size.height*scale))
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext saveGraphicsState];
    CGContextTranslateCTM(context.CGContext,0,rep.pixelsHigh);CGContextScaleCTM(context.CGContext,scale,-scale);
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithCGContext:context.CGContext flipped:YES];
    [self drawItem:item rect:NSMakeRect(0,0,size.width,size.height) alpha:1 selected:selected];
    [NSGraphicsContext restoreGraphicsState];
    return CGImageRetain(rep.CGImage);
}
- (void)syncItems:(NSArray *)items strip:(CALayer *)strip map:(NSMutableDictionary *)map page:(NSInteger)page viewport:(NSRect)viewport animated:(BOOL)animated {
    NSInteger capacity=[self capacity];CGFloat width=viewport.size.width;
    strip.bounds=NSMakeRect(0,0,width*MAX(1,(items.count+capacity-1)/capacity),viewport.size.height);
    strip.position=NSMakePoint(-page*width+(self.trackingScroll?self.slideOffset:0),0);
    NSMutableSet *visible=[NSMutableSet set];
    NSInteger first=MAX(0,(page-1)*capacity),last=MIN((NSInteger)items.count,(page+2)*capacity);
    for(NSInteger i=first;i<last;i++){
        NSDictionary *item=items[i];NSString *ident=item[@"id"];[visible addObject:ident];
        NSRect cell=[self cell:i];cell.origin.x-=viewport.origin.x;cell.origin.y-=viewport.origin.y;
        cell.origin.x+=(i/capacity)*width;
        CALayer *layer=map[ident];BOOL created=!layer;
        if(created){layer=[CALayer layer];layer.contentsScale=self.window.backingScaleFactor?:2;map[ident]=layer;[strip addSublayer:layer];}
        BOOL selected=(items==self.items&&i==self.selected);
        NSString *signature=[NSString stringWithFormat:@"%@|%@|%ld|%.1f,%.1f|%d,%d",item[@"name"],item[@"paths"],(long)[item[@"count"]integerValue],cell.size.width,cell.size.height,self.editing,selected];
        if(![[layer valueForKey:@"signature"]isEqual:signature]){
            CGImageRef image=[self texture:item size:cell.size selected:selected];layer.contents=(__bridge id)image;CGImageRelease(image);[layer setValue:signature forKey:@"signature"];
        }
        CGPoint old=layer.presentationLayer?layer.presentationLayer.position:layer.position;
        layer.bounds=NSMakeRect(0,0,cell.size.width,cell.size.height);layer.position=NSMakePoint(NSMidX(cell),NSMidY(cell));[layer setValue:item forKey:@"item"];
        layer.opacity=(self.dragging&&[ident isEqual:self.dragItem[@"id"]])?.22:1;
        if(animated&&!created&&!CGPointEqualToPoint(old,layer.position))LPAnimate(layer,@"position",[NSValue valueWithPoint:old],[NSValue valueWithPoint:layer.position],.28);
        if(animated&&created){LPAnimate(layer,@"opacity",@0,@1,.22);LPSpring(layer,[item[@"count"]integerValue]>1?.78:.94);}
    }
    for(NSString *ident in map.allKeys){
        if([visible containsObject:ident])continue;
        CALayer *old=map[ident];NSDictionary *oldItem=[old valueForKey:@"item"];
        BOOL stillExists=[items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"id == %@",ident]].count>0;
        if(animated&&!stillExists){
            CALayer *destination=nil;
            for(NSString *candidate in visible){NSDictionary *item=[map[candidate]valueForKey:@"item"];
                if([item[@"count"]integerValue]>1&&[item[@"paths"]containsObject:[oldItem[@"paths"]firstObject]]){destination=map[candidate];break;}}
            CGPoint from=old.presentationLayer?old.presentationLayer.position:old.position;
            if(destination){old.position=destination.position;LPAnimate(old,@"position",[NSValue valueWithPoint:from],[NSValue valueWithPoint:old.position],.30);}
            old.opacity=0;LPAnimate(old,@"opacity",@1,@0,.25);LPAnimate(old,@"transform.scale",@1,@.18,.30);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,320*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[old removeFromSuperlayer];});
        }else [old removeFromSuperlayer];
        [map removeObjectForKey:ident];
    }
}
- (void)dots:(CALayer *)layer count:(NSInteger)count page:(NSInteger)page center:(NSPoint)center {
    NSString *key=[NSString stringWithFormat:@"%ld:%ld:%.1f:%.1f",(long)count,(long)page,center.x,center.y];
    if([[layer valueForKey:@"signature"]isEqual:key])return;
    layer.sublayers=nil;[layer setValue:key forKey:@"signature"];
    for(NSInteger i=0;i<count;i++){
        CALayer *dot=[CALayer layer];dot.frame=NSMakeRect(center.x+(i-(count-1)/2.0)*18-3,center.y,6,6);
        dot.cornerRadius=3;dot.backgroundColor=[NSColor colorWithWhite:1 alpha:i==page?.95:.35].CGColor;[layer addSublayer:dot];
    }
}
- (void)syncScene:(BOOL)animated {
    if(!self.sceneReady)return;
    [CATransaction begin];[CATransaction setDisableActions:YES];
    NSString *folder=self.folder;BOOL open=folder.length>0,changed=open!=self.folderOpen;
    CALayer *panel=self.folderSurface.layer;
    NSRect panelRect=[self folderRect];
    CGPoint oldPanelPosition=panel.presentationLayer?panel.presentationLayer.position:panel.position;
    CGFloat oldPanelScale=panel.presentationLayer?[[panel.presentationLayer valueForKeyPath:@"transform.scale"]doubleValue]:1;
    CGFloat oldOpacity=self.rootViewport.presentationLayer?self.rootViewport.presentationLayer.opacity:self.rootViewport.opacity;
    NSPoint folderOrigin=NSMakePoint(NSMidX(panelRect),NSMidY(panelRect));
    NSDictionary *folderItem=nil;
    NSString *anchor=open?folder:[panel valueForKey:@"folder"];
    for(NSInteger i=0;i<(NSInteger)self.rootItems.count;i++)if([self.rootItems[i][@"id"]isEqual:anchor]){
        NSString *saved=self.folder;self.folder=@"";NSRect cell=[self cell:i];self.folder=saved;
        folderOrigin=NSMakePoint(NSMidX(cell),NSMidY(cell)-12);folderItem=self.rootItems[i];break;
    }
    self.folder=@"";
    self.rootViewport.frame=NSMakeRect(0,self.gridTop,self.bounds.size.width,MAX(1,self.bounds.size.height-self.gridTop-90));
    [self syncItems:open?self.rootItems:self.items strip:self.rootStrip map:self.rootIcons page:self.page viewport:self.rootViewport.frame animated:animated];
    NSInteger rootCount=MAX(1,((open?self.rootItems:self.items).count+34)/35);
    self.rootDots.frame=self.bounds;[self dots:self.rootDots count:rootCount page:self.page center:NSMakePoint(self.bounds.size.width/2,self.bounds.size.height-62)];
    self.folder=folder;
    self.rootViewport.opacity=open?.26:1;self.rootDots.opacity=open?.2:1;
    if(open){
        self.folderSurface.hidden=NO;self.folderSurface.frame=panelRect;panel.opacity=1;panel.transform=CATransform3DIdentity;
        [panel setValue:folder forKey:@"folder"];
        self.folderViewport.frame=NSMakeRect(24,60,panelRect.size.width-48,panelRect.size.height-89);
        NSRect viewport=NSOffsetRect(self.folderViewport.frame,panelRect.origin.x,panelRect.origin.y);
        [self syncItems:self.items strip:self.folderStrip map:self.folderIcons page:self.folderPage viewport:viewport animated:animated];
        self.folderDots.frame=panel.bounds;[self dots:self.folderDots count:[self pageCount] page:self.folderPage center:NSMakePoint(panelRect.size.width/2,panelRect.size.height-20)];
        if(changed){
            LPAnimate(panel,@"position",[NSValue valueWithPoint:folderOrigin],[NSValue valueWithPoint:panel.position],.30);
            LPAnimate(panel,@"transform.scale",@.16,@1,.30);LPAnimate(panel,@"opacity",@0,@1,.20);
        }
    }else if(changed){
        panel.position=folderOrigin;panel.transform=CATransform3DMakeScale(.16,.16,1);panel.opacity=0;
        LPAnimate(panel,@"position",[NSValue valueWithPoint:oldPanelPosition],[NSValue valueWithPoint:folderOrigin],.26);
        LPAnimate(panel,@"transform.scale",@(oldPanelScale),@.16,.26);LPAnimate(panel,@"opacity",@1,@0,.22);
        NSUInteger generation=++self.sceneGeneration;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,280*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(generation==self.sceneGeneration&&!self.folder.length)self.folderSurface.hidden=YES;});
    }else if(!self.folderOpen&&!panel.animationKeys.count)self.folderSurface.hidden=YES;
    if(changed){
        if(open)self.sceneGeneration++;
        LPAnimate(self.rootViewport,@"opacity",@(oldOpacity),@(self.rootViewport.opacity),.28);
        LPAnimate(self.rootDots,@"opacity",@(open?1:.2),@(self.rootDots.opacity),.28);
    }
    self.folderOpen=open;
    (void)folderItem;
    if(self.dragging&&self.dragItem){
        if(![[self.ghostLayer valueForKey:@"id"]isEqual:self.dragItem[@"id"]]){
            CGImageRef texture=[self texture:self.dragItem size:NSMakeSize(110,115) selected:NO];self.ghostLayer.contents=(__bridge id)texture;CGImageRelease(texture);[self.ghostLayer setValue:self.dragItem[@"id"]forKey:@"id"];
        }
        self.ghostLayer.frame=NSMakeRect(self.dragPoint.x-55,self.dragPoint.y-48,110,115);self.ghostLayer.opacity=.95;
        NSInteger hit=[self hit:self.dragPoint];NSString *hover=@"";
        if(hit>=0&&!open){NSRect cell=[self cell:hit];if(fabs(self.dragPoint.x-NSMidX(cell))<cell.size.width*.25&&fabs(self.dragPoint.y-NSMidY(cell))<cell.size.height*.32&&![[self.items[hit]objectForKey:@"id"]isEqual:self.dragItem[@"id"]])hover=self.items[hit][@"id"];}
        if(![hover isEqual:self.hoverID]){
            CALayer *previous=self.rootIcons[self.hoverID];previous.transform=CATransform3DIdentity;
            if(previous)LPAnimate(previous,@"transform.scale",@1.08,@1,.16);
            self.hoverID=hover;CALayer *target=self.rootIcons[hover];
            if(target){target.transform=CATransform3DMakeScale(1.08,1.08,1);LPAnimate(target,@"transform.scale",@1,@1.08,.16);}
        }
        if(hover.length){NSRect cell=[self cell:hit];self.hoverRing.frame=NSMakeRect(NSMidX(cell)-51,NSMidY(cell)-63,102,102);CGPathRef path=CGPathCreateWithRoundedRect(CGRectMake(0,0,102,102),22,22,NULL);self.hoverRing.path=path;CGPathRelease(path);self.hoverRing.opacity=1;}else self.hoverRing.opacity=0;
    }else{
        self.hoverRing.opacity=0;CALayer *target=self.rootIcons[self.hoverID];target.transform=CATransform3DIdentity;self.hoverID=@"";
        if(!self.ghostSettling)self.ghostLayer.opacity=0;
    }
    [CATransaction commit];
}
- (void)settleGhostAt:(NSPoint)point merged:(BOOL)merged {
    self.ghostSettling=YES;
    [CATransaction begin];[CATransaction setDisableActions:YES];
    CGPoint from=self.ghostLayer.position;self.ghostLayer.position=point;self.ghostLayer.opacity=0;
    LPAnimate(self.ghostLayer,@"position",[NSValue valueWithPoint:from],[NSValue valueWithPoint:point],.28);
    LPAnimate(self.ghostLayer,@"opacity",@.95,@0,.28);
    LPAnimate(self.ghostLayer,@"transform.scale",@1,merged?@.22:@1,.28);
    [CATransaction commit];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),dispatch_get_main_queue(),^{self.ghostSettling=NO;});
}
- (void)resetScene {
    self.trackingScroll=NO;self.slideOffset=0;self.folderOpen=NO;self.ghostSettling=NO;self.sceneGeneration++;
    self.folderSurface.hidden=YES;self.folderSurface.layer.opacity=0;
    [self.rootStrip removeAllAnimations];[self.folderStrip removeAllAnimations];[self.folderSurface.layer removeAllAnimations];
    self.rootViewport.opacity=1;[self.rootViewport removeAllAnimations];self.ghostLayer.opacity=0;
}
