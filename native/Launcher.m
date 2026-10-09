#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Carbon/Carbon.h>
#import "Animation.h"

extern void lp_refresh(void);
extern char *lp_items(const char *, const char *);
extern void lp_free(char *);
extern void lp_action(int, const char *, const char *, size_t);
extern void lp_diagnostic_group(const char *,const char *);
extern bool lp_gesture_start(void (*)(int));
extern void lp_gesture_stop(void);
extern bool lp_gesture_enabled(void);
extern int lp_gesture_contacts(void);
extern const char *lp_gesture_status(void);
extern void lp_gesture_threshold(float);

char *lp_app_name(const char *path) {
    @autoreleasepool {
        NSString *p = @(path);
        NSBundle *b = [NSBundle bundleWithPath:p];
        NSString *name = [b objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: [b objectForInfoDictionaryKey:@"CFBundleName"];
        if (![name isKindOfClass:NSString.class] || !name.length) name = p.lastPathComponent.stringByDeletingPathExtension;
        return strdup(name.UTF8String);
    }
}
void lp_free_native(char *p) { free(p); }
static NSString *Decode(NSString *s) {
    NSMutableData *d = [NSMutableData data];
    for (NSUInteger i=0; i+1<s.length; i+=2) { unsigned v=0; [[NSScanner scannerWithString:[s substringWithRange:NSMakeRange(i,2)]] scanHexInt:&v]; uint8_t b=v; [d appendBytes:&b length:1]; }
    return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: @"";
}
static NSArray<NSDictionary *> *Items(NSString *query, NSString *folder) {
    char *raw=lp_items(query.UTF8String,folder.UTF8String);
    NSString *s=@(raw); lp_free(raw);
    NSMutableArray *rows=[NSMutableArray array];
    for (NSString *line in [s componentsSeparatedByString:@"\n"]) {
        NSArray *f=[line componentsSeparatedByString:@"\t"]; if(f.count!=4)continue;
        NSMutableArray *paths=[NSMutableArray array];
        for(NSString *p in [f[3] componentsSeparatedByString:@","]) if(p.length)[paths addObject:Decode(p)];
        [rows addObject:@{@"id":Decode(f[0]),@"name":Decode(f[1]),@"count":@([f[2] integerValue]),@"paths":paths}];
    }
    return rows;
}
@class LPController;
@interface LPWindow:NSWindow @end
@implementation LPWindow
- (BOOL)canBecomeKeyWindow{return YES;}
- (BOOL)canBecomeMainWindow{return YES;}
@end
@interface LPBackground:NSVisualEffectView @end
@implementation LPBackground
- (BOOL)isFlipped{return YES;}
@end
#import "Search.h"
@interface LPFolderSurface:NSView @end
@implementation LPFolderSurface
- (BOOL)isFlipped{return YES;}
- (NSView *)hitTest:(NSPoint)point {NSView *hit=[super hitTest:point];return hit==self?nil:hit;}
@end
@interface LPView:NSView<NSDraggingSource>
@property(nonatomic,weak) LPController *controller;
@property(nonatomic,strong) NSArray<NSDictionary *> *items;
@property(nonatomic,strong) NSArray<NSDictionary *> *rootItems;
@property(nonatomic,strong) NSMutableDictionary<NSString *,NSImage *> *icons;
@property(nonatomic,copy) NSString *folder;
@property(nonatomic) NSInteger page,folderPage,selected;
@property(nonatomic) BOOL editing;
@property(nonatomic) NSPoint downPoint,dragPoint;
@property(nonatomic) NSInteger downIndex;
@property(nonatomic,strong) NSDictionary *dragItem;
@property(nonatomic,strong) NSURL *externalURL;
@property(nonatomic,strong) NSTimer *holdTimer,*edgeTimer;
@property(nonatomic) CGFloat scrollSum,magnification;
@property(nonatomic) BOOL scrollConsumed,dragging;
@property(nonatomic) NSTimeInterval lastPage;
@property(nonatomic) CGFloat slideOffset,lastScrollDelta;
@property(nonatomic) NSTimeInterval lastScrollTime;
@property(nonatomic) BOOL trackingScroll,sceneReady,folderOpen,ghostSettling,animateLayout,externalDragging,dragExtracted;
@property(nonatomic) CGFloat gridTop;
@property(nonatomic) NSUInteger sceneGeneration;
@property(nonatomic,strong) CALayer *rootViewport,*rootStrip,*folderViewport,*folderStrip,*ghostLayer,*rootDots,*folderDots;
@property(nonatomic,strong) CAShapeLayer *hoverRing;
@property(nonatomic,strong) LPFolderSurface *folderSurface;
@property(nonatomic,strong) NSMutableDictionary<NSString *,CALayer *> *rootIcons,*folderIcons;
@property(nonatomic,copy) NSString *hoverID;
- (void)reload;
- (void)changePage:(NSInteger)delta;
- (void)closeFolder;
- (void)syncScene:(BOOL)animated;
- (void)openFolder:(NSString *)folder;
- (void)resetScene;
- (void)finishScroll;
- (NSRect)cell:(NSInteger)index;
- (NSRect)folderRect;
@end
@interface LPController:NSObject<NSApplicationDelegate,NSSearchFieldDelegate,NSTextFieldDelegate,NSWindowDelegate>
@property(nonatomic,strong) LPWindow *window;
@property(nonatomic,strong) LPView *grid;
@property(nonatomic,strong) LPBackground *background;
@property(nonatomic) BOOL opening,closing;
@property(nonatomic,strong) NSTextField *search;
@property(nonatomic,strong) LPSearchBox *searchBox;
@property(nonatomic,strong) NSButton *settingsButton;
@property(nonatomic,strong) NSTextField *folderName;
@property(nonatomic,strong) NSStatusItem *status;
@property(nonatomic,strong) NSMenu *menu;
@property(nonatomic,strong) id localMonitor;
@property(nonatomic) BOOL scanning;
@property(nonatomic) BOOL presentingDialog;
@property(nonatomic,copy) NSString *previewPath;
@property(nonatomic,strong) NSWindow *settingsWindow;
@property(nonatomic,strong) NSButton *shortcutButton,*gestureButton;
@property(nonatomic,strong) NSSlider *gestureSlider;
@property(nonatomic,strong) NSTextField *settingsStatus;
@property(nonatomic,strong) NSTimer *settingsTimer;
@property(nonatomic) BOOL recordingShortcut;
@property(nonatomic) UInt16 shortcutCode;
@property(nonatomic) UInt32 shortcutModifiers;
@property(nonatomic,copy) NSString *shortcutName;
@property(nonatomic) EventHotKeyRef hotkey;
@property(nonatomic) EventHandlerRef hotkeyHandler;
- (void)toggle;
- (void)show;
- (void)dismiss;
- (void)refresh;
- (void)launch:(NSDictionary *)item;
- (NSModalResponse)runAlert:(NSAlert *)alert;
- (void)presentPanel;
- (NSEvent *)filterKeyEvent:(NSEvent *)event;
- (void)settings;
- (void)clearSearch:(id)sender;
- (void)recordShortcut:(id)sender;
- (void)cancelShortcutRecording;
- (BOOL)registerShortcut:(UInt16)code modifiers:(UInt32)mods name:(NSString *)name persist:(BOOL)persist;
- (NSEvent *)recordShortcutEvent:(NSEvent *)event;
- (NSEvent *)recordShortcutEvent:(NSEvent *)event persist:(BOOL)persist;
- (void)updateGestureStatus;
- (void)trashApplication:(NSURL *)url;
@end

@implementation LPView
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])){
        self.icons=[NSMutableDictionary dictionary];self.folder=@"";self.items=@[];self.rootItems=@[];
        self.selected=-1;self.downIndex=-1;self.hoverID=@"";self.gridTop=100;self.wantsLayer=YES;
        [self setupScene];
    }return self;
}
- (BOOL)isFlipped{return YES;}
- (BOOL)acceptsFirstResponder{return YES;}
- (NSInteger)columns{return self.folder.length?4:7;}
- (NSInteger)capacity{return self.folder.length?12:35;}
- (NSInteger)currentPage{return self.folder.length?self.folderPage:self.page;}
- (NSInteger)pageCount{return MAX(1,(self.items.count+[self capacity]-1)/[self capacity]);}
- (NSRect)folderRect {CGFloat w=MIN(680,self.bounds.size.width-100),h=MIN(450,self.bounds.size.height-180);return NSMakeRect((self.bounds.size.width-w)/2,140,w,h);}
- (NSRect)gridRect {if(self.folder.length){NSRect r=[self folderRect];return NSInsetRect(NSMakeRect(r.origin.x,r.origin.y+48,r.size.width,r.size.height-65),24,12);}return NSMakeRect(MAX(40,self.bounds.size.width*.09),self.gridTop,self.bounds.size.width-MAX(40,self.bounds.size.width*.09)*2,self.bounds.size.height-self.gridTop-90);}
- (NSRect)cell:(NSInteger)index {
    NSRect grid=[self gridRect];NSInteger local=index%[self capacity],cols=[self columns],rows=self.folder.length?3:5;
    CGFloat w=grid.size.width/cols,h=grid.size.height/rows;
    return NSMakeRect(grid.origin.x+(local%cols)*w,grid.origin.y+(local/cols)*h,w,h);
}
- (NSInteger)hit:(NSPoint)p {
    NSInteger start=[self currentPage]*[self capacity],end=MIN(start+[self capacity],(NSInteger)self.items.count);
    for(NSInteger i=start;i<end;i++){NSRect r=NSInsetRect([self cell:i],7,4);if(NSPointInRect(p,r))return i;}return -1;
}
- (NSImage *)icon:(NSString *)path {
    NSImage *image=self.icons[path];
    if(!image){image=LPRasterIcon(path);self.icons[path]=image;}
    return image;
}
- (void)reload {
    self.rootItems=Items(@"",@"");
    if(self.folder.length && ![self.rootItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"id == %@ AND count > 1",self.folder]].count)self.folder=@"";
    self.items=Items(self.controller.search.stringValue,self.folder);
    if(self.folder.length)self.folderPage=MIN(self.folderPage,[self pageCount]-1);else self.page=MIN(self.page,[self pageCount]-1);
    self.selected=MIN(self.selected,(NSInteger)self.items.count-1);
    self.controller.folderName.hidden=NO;
    if(self.folder.length){NSDictionary *folder=[self.rootItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"id == %@",self.folder]].firstObject;self.controller.folderName.stringValue=folder[@"name"]?:@"文件夹";NSRect r=[self folderRect];self.controller.folderName.frame=NSMakeRect(40,12,r.size.width-80,32);}
    [self.controller.searchBox setNeedsLayout:YES];
    [self setNeedsDisplay:YES];
}
- (void)drawItem:(NSDictionary *)item rect:(NSRect)cell alpha:(CGFloat)alpha selected:(BOOL)selected {
    CGFloat size=MIN(self.folder.length?76:86,cell.size.height-34);size=MAX(38,size);
    NSRect icon=NSMakeRect(NSMidX(cell)-size/2,cell.origin.y+MAX(4,(cell.size.height-size-28)/2),size,size);
    if(selected){[[NSColor colorWithWhite:1 alpha:.17*alpha] setFill];[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(cell,5,2) xRadius:16 yRadius:16] fill];}
    NSArray *paths=item[@"paths"];
    if([item[@"count"] integerValue]>1){
        [[NSColor colorWithWhite:.92 alpha:.28*alpha] setFill];[[NSBezierPath bezierPathWithRoundedRect:icon xRadius:16 yRadius:16] fill];
        CGFloat small=size*.25,gap=size*.045;
        for(NSUInteger j=0;j<MIN(9,paths.count);j++){NSRect r=NSMakeRect(icon.origin.x+size*.08+(j%3)*(small+gap),icon.origin.y+size*.08+(j/3)*(small+gap),small,small);[[self icon:paths[j]] drawInRect:r fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:alpha respectFlipped:YES hints:nil];}
    }else if(paths.count){[[self icon:paths.firstObject] drawInRect:icon fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:alpha respectFlipped:YES hints:nil];}
    NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];style.alignment=NSTextAlignmentCenter;style.lineBreakMode=NSLineBreakByTruncatingTail;
    NSShadow *shadow=[NSShadow new];shadow.shadowColor=[NSColor colorWithWhite:0 alpha:.7];shadow.shadowBlurRadius=3;shadow.shadowOffset=NSMakeSize(0,-1);
    NSDictionary *attrs=@{NSFontAttributeName:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium],NSForegroundColorAttributeName:[NSColor colorWithWhite:1 alpha:alpha],NSParagraphStyleAttributeName:style,NSShadowAttributeName:shadow};
    [item[@"name"] drawInRect:NSMakeRect(cell.origin.x+4,NSMaxY(icon)+5,cell.size.width-8,22) withAttributes:attrs];
    if(self.editing){[[NSColor colorWithWhite:1 alpha:.9]setFill];NSRect badge=NSMakeRect(icon.origin.x-4,icon.origin.y-3,20,20);[[NSBezierPath bezierPathWithOvalInRect:badge]fill];[@"−" drawInRect:badge withAttributes:@{NSFontAttributeName:[NSFont boldSystemFontOfSize:17],NSForegroundColorAttributeName:NSColor.darkGrayColor,NSParagraphStyleAttributeName:style}];}
}
#include "Scene.inc"
- (void)drawRect:(NSRect)dirty {
    [super drawRect:dirty];
    if(!self.items.count){
        NSString *label=self.controller.scanning?@"正在读取应用…":@"没有找到应用";
        NSSize size=[label sizeWithAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:18]}];
        [label drawAtPoint:NSMakePoint((self.bounds.size.width-size.width)/2,self.bounds.size.height/2)
            withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:18],NSForegroundColorAttributeName:NSColor.whiteColor}];
    }
    if(self.editing)[@"拖到图标中心建立文件夹 · 拖到两侧翻页 · Esc 完成"
        drawAtPoint:NSMakePoint(24,self.bounds.size.height-27)
        withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11],NSForegroundColorAttributeName:[NSColor colorWithWhite:1 alpha:.6]}];
}
- (void)changePage:(NSInteger)delta {
    NSInteger old=[self currentPage],next=MAX(0,MIN([self pageCount]-1,old+delta));
    CALayer *strip=self.folder.length?self.folderStrip:self.rootStrip;
    CGFloat width=(self.folder.length?self.folderViewport:self.rootViewport).bounds.size.width;
    CGFloat from=strip.presentationLayer?strip.presentationLayer.position.x:strip.position.x;
    if(self.trackingScroll)from=strip.position.x;
    self.trackingScroll=NO;self.slideOffset=0;
    if(self.folder.length)self.folderPage=next;else self.page=next;
    self.selected=-1;self.lastPage=NSDate.timeIntervalSinceReferenceDate;
    [self syncScene:NO];
    LPAnimate(strip,@"position.x",@(from),@(-next*width),.32);
}
- (void)finishScroll {
    if(!self.trackingScroll)return;
    CGFloat width=(self.folder.length?self.folderViewport:self.rootViewport).bounds.size.width;
    BOOL flick=NSDate.timeIntervalSinceReferenceDate-self.lastScrollTime<.12&&fabs(self.lastScrollDelta)>4;
    NSInteger delta=(fabs(self.scrollSum)>MAX(60,width*.10)||flick)?(self.scrollSum<0?1:-1):0;
    [self changePage:delta];self.scrollSum=0;
}
- (void)scrollWheel:(NSEvent *)event {
    if(event.momentumPhase!=NSEventPhaseNone)return;
    if(event.hasPreciseScrollingDeltas&&event.phase!=NSEventPhaseNone&&!LPReduceMotion()){
        if(event.phase==NSEventPhaseBegan){
            CALayer *strip=self.folder.length?self.folderStrip:self.rootStrip;
            CGFloat width=(self.folder.length?self.folderViewport:self.rootViewport).bounds.size.width;
            CGFloat x=strip.presentationLayer?strip.presentationLayer.position.x:strip.position.x;
            self.scrollSum=x+[self currentPage]*width;self.lastScrollDelta=0;self.trackingScroll=YES;
            [CATransaction begin];[CATransaction setDisableActions:YES];[strip removeAllAnimations];strip.position=NSMakePoint(x,0);[CATransaction commit];
        }
        if(event.scrollingDeltaX!=0){
            self.trackingScroll=YES;self.scrollSum+=event.scrollingDeltaX;self.lastScrollDelta=event.scrollingDeltaX;self.lastScrollTime=NSDate.timeIntervalSinceReferenceDate;
            CGFloat width=(self.folder.length?self.folderViewport:self.rootViewport).bounds.size.width;
            CGFloat offset=MAX(-width*.95,MIN(width*.95,self.scrollSum));
            if(([self currentPage]==0&&offset>0)||([self currentPage]==[self pageCount]-1&&offset<0))offset*=.24;
            self.slideOffset=offset;
            [CATransaction begin];[CATransaction setDisableActions:YES];
            (self.folder.length?self.folderStrip:self.rootStrip).position=NSMakePoint(-[self currentPage]*width+offset,0);
            [CATransaction commit];
        }
        if(event.phase==NSEventPhaseCancelled){self.scrollSum=0;self.lastScrollDelta=0;[self finishScroll];}
        else if(event.phase==NSEventPhaseEnded)[self finishScroll];
        return;
    }
    if(event.phase==NSEventPhaseBegan||NSDate.timeIntervalSinceReferenceDate-self.lastPage>.3){self.scrollSum=0;self.scrollConsumed=NO;}
    if(!self.scrollConsumed){self.scrollSum+=fabs(event.scrollingDeltaX)>fabs(event.scrollingDeltaY)?event.scrollingDeltaX:event.scrollingDeltaY;
        if(fabs(self.scrollSum)>(event.hasPreciseScrollingDeltas?48:8)){[self changePage:self.scrollSum<0?1:-1];self.scrollConsumed=YES;}}
    if(event.phase==NSEventPhaseEnded||event.phase==NSEventPhaseCancelled){self.scrollSum=0;self.scrollConsumed=NO;}
}
- (void)swipeWithEvent:(NSEvent *)event {if(event.deltaX)[self changePage:event.deltaX<0?1:-1];}
- (void)magnifyWithEvent:(NSEvent *)event {if(event.phase==NSEventPhaseBegan)self.magnification=0;self.magnification+=event.magnification;if(self.magnification>.25){self.magnification=0;[self.controller dismiss];}}
- (void)closeFolder {
    [self.window makeFirstResponder:self];self.folder=@"";self.selected=-1;[self reload];
}
- (void)openFolder:(NSString *)folder {
    self.folder=folder;self.folderPage=0;self.selected=-1;[self reload];
}
- (void)mouseDown:(NSEvent *)event {
    self.dragItem=nil;self.dragExtracted=NO;
    [self.window makeFirstResponder:self];self.downPoint=[self convertPoint:event.locationInWindow fromView:nil];self.downIndex=[self hit:self.downPoint];self.dragging=NO;
    NSInteger pages=[self pageCount];CGFloat y=self.folder.length?NSMaxY([self folderRect])-20:self.bounds.size.height-62;
    if(fabs(self.downPoint.y-y-3)<12 && fabs(self.downPoint.x-self.bounds.size.width/2)<pages*9+8){NSInteger dot=lround((self.downPoint.x-self.bounds.size.width/2)/18+(pages-1)/2.0);[self changePage:MAX(0,MIN(pages-1,dot))-[self currentPage]];self.downIndex=-1;return;}
    if(self.downIndex<0){if(self.folder.length)[self closeFolder];else if(self.editing){self.editing=NO;[self setNeedsDisplay:YES];}else[self.controller dismiss];return;}
    self.selected=self.downIndex;self.dragItem=self.items[self.downIndex];[self setNeedsDisplay:YES];
    __weak LPView *weak=self;self.holdTimer=[NSTimer scheduledTimerWithTimeInterval:.55 repeats:NO block:^(NSTimer *t){weak.editing=YES;[weak setNeedsDisplay:YES];}];
}
- (void)mouseDragged:(NSEvent *)event {
    if(!self.dragItem||self.controller.search.stringValue.length)return;
    self.dragPoint=[self convertPoint:event.locationInWindow fromView:nil];if(hypot(self.dragPoint.x-self.downPoint.x,self.dragPoint.y-self.downPoint.y)<5&&!self.dragging)return;
    [self.holdTimer invalidate];if(!self.dragging){[self.ghostLayer removeAllAnimations];self.ghostSettling=NO;}self.dragging=YES;self.editing=YES;
    if([self beginDockDrag:event])return;
    if(self.folder.length&&!NSPointInRect(self.dragPoint,[self folderRect])){NSString *id=self.dragItem[@"id"];lp_action(3,id.UTF8String,"",self.page*35);self.dragExtracted=YES;[self closeFolder];self.downIndex=-1;}
    if(!self.edgeTimer){__weak LPView *weak=self;self.edgeTimer=[NSTimer scheduledTimerWithTimeInterval:.65 repeats:YES block:^(NSTimer *t){if(weak.dragPoint.x<55)[weak changePage:-1];else if(weak.dragPoint.x>weak.bounds.size.width-55)[weak changePage:1];}];}
    [self setNeedsDisplay:YES];
}
- (void)mouseUp:(NSEvent *)event {
    if(self.externalDragging)return;
    BOOL held=self.holdTimer&&!self.holdTimer.valid;[self.holdTimer invalidate];self.holdTimer=nil;[self.edgeTimer invalidate];self.edgeTimer=nil;
    NSPoint p=[self convertPoint:event.locationInWindow fromView:nil];NSInteger target=[self hit:p];
    if(self.dragging&&self.dragItem){
        NSString *source=self.dragItem[@"id"]; BOOL merged=NO;NSPoint destination=p;
        if(!self.folder.length){
            if(target>=0){NSDictionary *other=self.items[target];NSRect cell=[self cell:target];BOOL center=fabs(p.x-NSMidX(cell))<cell.size.width*.25 && fabs(p.y-NSMidY(cell))<cell.size.height*.32;
                if(center&&![source isEqual:other[@"id"]]){merged=YES;destination=NSMakePoint(NSMidX(cell),NSMidY(cell)-12);lp_action(1,source.UTF8String,[other[@"id"]UTF8String],target);}else lp_action(0,source.UTF8String,"",target);
            }else lp_action(0,source.UTF8String,"",MIN((NSInteger)self.items.count,[self currentPage]*[self capacity]+[self capacity]-1));
        }else if(target>=0){lp_action(6,source.UTF8String,self.folder.UTF8String,target);}
        self.dragging=NO;[self settleGhostAt:destination merged:merged];
        self.animateLayout=YES;[self reload];self.animateLayout=NO;
    }else if(target>=0&&target==self.downIndex&&!held){
        NSDictionary *item=self.items[target];
        if(self.editing){NSRect cell=[self cell:target];if(p.x<NSMidX(cell)-20&&p.y<NSMidY(cell)-10){[self hideItem:item];}else if([item[@"count"]integerValue]>1)[self.controller launch:item];}
        else[self.controller launch:item];
    }
    self.dragging=NO;self.dragItem=nil;self.downIndex=-1;[self setNeedsDisplay:YES];
}
- (BOOL)beginDockDrag:(NSEvent *)event {
    if([self.dragItem[@"count"]integerValue]!=1)return NO;
    NSString *path=[self.dragItem[@"paths"]firstObject];if(!path)return NO;
    NSScreen *screen=self.window.screen;
    NSString *orientation=[[NSUserDefaults.standardUserDefaults persistentDomainForName:@"com.apple.dock"]objectForKey:@"orientation"]?:@"bottom";
    CGFloat edge=28;BOOL near=NO;
    if([orientation isEqual:@"left"]){edge=MAX(edge,NSMinX(screen.visibleFrame)-NSMinX(screen.frame)+12);near=self.dragPoint.x<edge;}
    else if([orientation isEqual:@"right"]){edge=MAX(edge,NSMaxX(screen.frame)-NSMaxX(screen.visibleFrame)+12);near=self.dragPoint.x>self.bounds.size.width-edge;}
    else{edge=MAX(edge,NSMinY(screen.visibleFrame)-NSMinY(screen.frame)+12);near=self.dragPoint.y>self.bounds.size.height-edge;}
    if(!near)return NO;
    NSImage *icon=[self icon:path];
    if(self.dragExtracted){lp_action(7,"","",0);self.dragExtracted=NO;[self reload];}
    [self.holdTimer invalidate];[self.edgeTimer invalidate];self.holdTimer=nil;self.edgeTimer=nil;
    self.dragging=NO;self.dragItem=nil;self.selected=-1;self.externalDragging=YES;[self setNeedsDisplay:YES];
    self.externalURL=[NSURL fileURLWithPath:path];
    NSDraggingItem *item=[[NSDraggingItem alloc]initWithPasteboardWriter:self.externalURL];
    [item setDraggingFrame:NSMakeRect(self.dragPoint.x-40,self.dragPoint.y-40,80,80) contents:icon];
    NSDraggingSession *session=[self beginDraggingSessionWithItems:@[item]event:event source:self];
    session.animatesToStartingPositionsOnCancelOrFail=YES;return YES;
}
- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return NSDragOperationCopy|NSDragOperationLink|NSDragOperationMove|NSDragOperationDelete|NSDragOperationGeneric;
}
- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)point operation:(NSDragOperation)operation {
    self.externalDragging=NO;self.downIndex=-1;
    NSURL *url=self.externalURL;self.externalURL=nil;
    if((operation&NSDragOperationDelete)&&url&&[NSFileManager.defaultManager fileExistsAtPath:url.path]){
        [self.controller trashApplication:url];
    }else [self.controller refresh];
    if(operation!=NSDragOperationNone)[self.controller dismiss];
}
- (void)hideItem:(NSDictionary *)item {
    NSAlert *alert=[NSAlert new];alert.messageText=@"从 Launchpad2 隐藏应用？";alert.informativeText=@"这只移除这里的图标，不会删除磁盘上的应用。可从菜单恢复所有隐藏应用。";[alert addButtonWithTitle:@"隐藏"];[alert addButtonWithTitle:@"取消"];
    if([self.controller runAlert:alert]==NSAlertFirstButtonReturn){if([item[@"count"]integerValue]>1){for(NSDictionary *child in Items(@"",item[@"id"]))lp_action(4,[child[@"id"]UTF8String],"",0);}else lp_action(4,[item[@"id"]UTF8String],"",0);[self reload];}
}
- (void)rightMouseDown:(NSEvent *)event {
    NSInteger index=[self hit:[self convertPoint:event.locationInWindow fromView:nil]];if(index<0)return;self.selected=index;
    NSDictionary *item=self.items[index];NSMenu *menu=[NSMenu new];
    NSArray *titles=[item[@"count"]integerValue]>1?@[@"重命名文件夹",@"整理图标"]:@[@"在 Finder 中显示",@"隐藏应用",@"整理图标"];
    for(NSString *title in titles){NSMenuItem *entry=[[NSMenuItem alloc]initWithTitle:title action:@selector(contextAction:) keyEquivalent:@""];entry.target=self;entry.representedObject=item;[menu addItem:entry];}
    [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}
- (void)contextAction:(NSMenuItem *)sender {
    NSDictionary *item=sender.representedObject;
    if([sender.title isEqual:@"在 Finder 中显示"]){[NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:[item[@"paths"]firstObject]]]];[self.controller dismiss];}
    else if([sender.title isEqual:@"隐藏应用"])[self hideItem:item];
    else if([sender.title isEqual:@"重命名文件夹"]){[self.controller launch:item];[self.window makeFirstResponder:self.controller.folderName];[self.controller.folderName selectText:nil];}
    else{self.editing=YES;[self setNeedsDisplay:YES];}
}
- (void)keyDown:(NSEvent *)event {
    NSString *chars=event.charactersIgnoringModifiers;unichar key=chars.length?[chars characterAtIndex:0]:0;
    if((event.modifierFlags&NSEventModifierFlagCommand)&&[chars.lowercaseString isEqual:@"z"]){lp_action((event.modifierFlags&NSEventModifierFlagShift)?8:7,"","",0);[self reload];return;}
    if(event.keyCode==53){if(self.folder.length)[self closeFolder];else if(self.controller.search.stringValue.length){[self.controller clearSearch:nil];}else if(self.editing){self.editing=NO;[self setNeedsDisplay:YES];}else[self.controller dismiss];return;}
    if(event.keyCode==36||event.keyCode==76){if(self.items.count)[self.controller launch:self.items[self.selected>=0?self.selected:[self currentPage]*[self capacity]]];return;}
    if(key==NSLeftArrowFunctionKey||key==NSRightArrowFunctionKey||key==NSUpArrowFunctionKey||key==NSDownArrowFunctionKey){
        NSInteger delta=key==NSLeftArrowFunctionKey?-1:key==NSRightArrowFunctionKey?1:key==NSUpArrowFunctionKey?-[self columns]:[self columns];
        if(event.modifierFlags&NSEventModifierFlagCommand){[self changePage:delta<0?-1:1];return;}
        self.selected=self.selected<0?[self currentPage]*[self capacity]:MAX(0,MIN((NSInteger)self.items.count-1,self.selected+delta));
        NSInteger p=MAX(0,self.selected)/[self capacity];if(self.folder.length)self.folderPage=p;else self.page=p;[self setNeedsDisplay:YES];return;
    }
    if(event.keyCode==51&&self.editing&&self.selected>=0&&self.selected<(NSInteger)self.items.count){[self hideItem:self.items[self.selected]];return;}
    if(chars.length&&!(event.modifierFlags&(NSEventModifierFlagCommand|NSEventModifierFlagControl))){if(self.folder.length)[self closeFolder];[self.window makeFirstResponder:self.controller.search];[self.controller.search.currentEditor keyDown:event];return;}
    [super keyDown:event];
}
@end

static __weak LPController *GestureController;
static void GestureAction(int action){
    dispatch_async(dispatch_get_main_queue(),^{
        LPController *controller=GestureController;
        if(!controller||!lp_gesture_enabled()||controller.recordingShortcut||controller.grid.dragging||controller.grid.externalDragging)return;
        if(action==1&&!controller.window.visible)[controller show];
        else if(action==2&&controller.window.visible)[controller dismiss];
    });
}
static OSStatus Hotkey(EventHandlerCallRef next,EventRef event,void *context){[(__bridge LPController *)context toggle];return noErr;}
@implementation LPController
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.previewPath=NSProcessInfo.processInfo.environment[@"LP_PREVIEW"];
    NSApp.activationPolicy=NSApplicationActivationPolicyAccessory;
    self.menu=[NSMenu new];
    NSArray *titles=@[@"打开 Launchpad2",@"设置…",@"重新扫描应用",@"恢复隐藏应用",@"使用说明",@"退出 Launchpad2"];
    NSArray *actions=@[NSStringFromSelector(@selector(toggle)),NSStringFromSelector(@selector(settings)),NSStringFromSelector(@selector(refresh)),NSStringFromSelector(@selector(restore)),NSStringFromSelector(@selector(help)),NSStringFromSelector(@selector(quit))];
    for(NSUInteger i=0;i<titles.count;i++){NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:titles[i] action:NSSelectorFromString(actions[i]) keyEquivalent:@""];item.target=self;[self.menu addItem:item];}
    self.status=[NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    self.status.button.image=[NSImage imageWithSystemSymbolName:@"square.grid.3x3.fill" accessibilityDescription:@"Launchpad2"];
    self.status.menu=self.menu;
    self.window=[[LPWindow alloc]initWithContentRect:NSMakeRect(0,0,1000,700) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    self.window.releasedWhenClosed=NO;self.window.opaque=NO;self.window.backgroundColor=NSColor.clearColor;self.window.hasShadow=NO;self.window.level=NSFloatingWindowLevel;
    self.window.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;self.window.delegate=self;
    LPBackground *background=[[LPBackground alloc]initWithFrame:self.window.contentView.bounds];background.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;background.wantsLayer=YES;
    background.material=NSVisualEffectMaterialHUDWindow;
    background.blendingMode=NSVisualEffectBlendingModeBehindWindow;
    background.state=NSVisualEffectStateActive;
    background.appearance=[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];self.background=background;
    self.window.contentView=background;
    self.grid=[[LPView alloc]initWithFrame:background.bounds];self.grid.controller=self;self.grid.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;[background addSubview:self.grid];
    self.searchBox=[[LPSearchBox alloc]initWithFrame:NSMakeRect(340,32,320,32)];
    self.search=self.searchBox.input;self.search.delegate=self;
    self.searchBox.clearButton.target=self;self.searchBox.clearButton.action=@selector(clearSearch:);
    [background addSubview:self.searchBox];
    self.settingsButton=[NSButton buttonWithTitle:@"设置"target:self action:@selector(settings)];
    self.settingsButton.image=[NSImage imageWithSystemSymbolName:@"gearshape"accessibilityDescription:@"设置"];
    self.settingsButton.imagePosition=NSImageLeft;self.settingsButton.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.settingsButton.frame=NSMakeRect(888,32,88,32);self.settingsButton.autoresizingMask=NSViewMinXMargin|NSViewMaxYMargin;
    [background addSubview:self.settingsButton];
    self.folderName=[[NSTextField alloc]initWithFrame:NSZeroRect];self.folderName.hidden=YES;self.folderName.delegate=self;self.folderName.alignment=NSTextAlignmentCenter;self.folderName.font=[NSFont systemFontOfSize:22 weight:NSFontWeightMedium];self.folderName.textColor=NSColor.whiteColor;self.folderName.backgroundColor=NSColor.clearColor;self.folderName.bordered=NO;self.folderName.focusRingType=NSFocusRingTypeNone;[self.grid.folderSurface addSubview:self.folderName];
    EventTypeSpec type={kEventClassKeyboard,kEventHotKeyPressed};
    InstallApplicationEventHandler(Hotkey,1,&type,(__bridge void *)self,&_hotkeyHandler);
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    self.shortcutCode=[defaults objectForKey:@"ShortcutKeyCode"]?[defaults integerForKey:@"ShortcutKeyCode"]:kVK_Space;
    self.shortcutModifiers=[defaults objectForKey:@"ShortcutModifiers"]?[defaults integerForKey:@"ShortcutModifiers"]:(controlKey|optionKey);
    self.shortcutName=[defaults stringForKey:@"ShortcutName"]?:@"Space";
    [self registerShortcut:self.shortcutCode modifiers:self.shortcutModifiers name:self.shortcutName persist:NO];
    GestureController=self;
    float threshold=[defaults objectForKey:@"PinchThreshold"]?[defaults floatForKey:@"PinchThreshold"]:.24;
    lp_gesture_threshold(threshold);
    if([defaults boolForKey:@"FiveFingerGesture"])lp_gesture_start(GestureAction);
    __weak LPController *weak=self;
    self.localMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event){return [weak filterKeyEvent:event];}];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(screenChanged:) name:NSWorkspaceActiveSpaceDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(screenChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
    [self refresh];
    if(self.previewPath.length){[self.window setFrame:NSMakeRect(0,0,1440,900) display:NO];self.searchBox.frame=NSMakeRect(560,32,320,32);[self.searchBox layout];self.settingsButton.frame=NSMakeRect(1328,32,88,32);}else[self show];
}
#include "Settings.inc"
- (NSEvent *)filterKeyEvent:(NSEvent *)event {
    if(self.recordingShortcut&&event.window==self.settingsWindow)return [self recordShortcutEvent:event];
    if(self.grid.externalDragging)return event;
    if(!self.window.visible||event.window!=self.window)return event;
    BOOL command=(event.modifierFlags&NSEventModifierFlagCommand)!=0;
    NSString *key=event.charactersIgnoringModifiers.lowercaseString;
    if(command&&[key isEqual:@","]){[self settings];return nil;}
    if(command&&[key isEqual:@"q"]){[self quit];return nil;}
    NSResponder *responder=self.window.firstResponder;
    NSTextView *editor=[responder isKindOfClass:NSTextView.class]&&[(NSTextView *)responder isFieldEditor]?(NSTextView *)responder:nil;
    if(editor&&command&&!(event.modifierFlags&(NSEventModifierFlagControl|NSEventModifierFlagOption))){
        SEL action=NULL;
        if([key isEqual:@"a"])action=@selector(selectAll:);
        else if([key isEqual:@"c"])action=@selector(copy:);
        else if([key isEqual:@"v"])action=@selector(paste:);
        else if([key isEqual:@"x"])action=@selector(cut:);
        else if([key isEqual:@"z"]){
            if(event.modifierFlags&NSEventModifierFlagShift){if(editor.undoManager.canRedo)[editor.undoManager redo];}
            else if(editor.undoManager.canUndo)[editor.undoManager undo];
            return nil;
        }
        if(action&&[NSApp sendAction:action to:editor from:self])return nil;
    }
    if(command&&(event.keyCode==123||event.keyCode==124)){[self.grid keyDown:event];return nil;}
    if(editor==self.search.currentEditor&&!command&&(event.keyCode==53||event.keyCode==125||event.keyCode==126||event.keyCode==36||event.keyCode==76)){
        [self.grid keyDown:event];return nil;
    }
    return event;
}
- (void)screenChanged:(NSNotification *)notification {if(self.window.visible)[self dismiss];}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {[self toggle];return NO;}
- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {[self show];}
- (void)toggle {if(self.closing)[self show];else if(self.window.visible||self.opening)[self dismiss];else[self show];}
- (void)show {
    self.closing=NO;self.opening=YES;
    NSScreen *screen=NSScreen.mainScreen;
    NSPoint mouse=NSEvent.mouseLocation;for(NSScreen *candidate in NSScreen.screens)if(NSPointInRect(mouse,candidate.frame)){screen=candidate;break;}
    [self.window setFrame:screen.frame display:NO];CGFloat menuInset=NSMaxY(screen.frame)-NSMaxY(screen.visibleFrame);
    if([screen respondsToSelector:@selector(safeAreaInsets)]){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
        menuInset=MAX(menuInset,screen.safeAreaInsets.top);
#pragma clang diagnostic pop
    }
    CGFloat searchY=MAX(32,menuInset+10);
    self.searchBox.frame=NSMakeRect((screen.frame.size.width-320)/2,searchY,320,32);[self.searchBox layout];
    self.settingsButton.frame=NSMakeRect(screen.frame.size.width-112,searchY,88,32);self.grid.gridTop=MAX(100,searchY+50);
    self.search.stringValue=@"";self.grid.folder=@"";self.grid.selected=-1;self.grid.editing=NO;[self.grid resetScene];[self.grid reload];
    [self presentPanel];
    [self refresh];
}
- (void)presentPanel {
    self.opening=NO;[self.background displayIfNeeded];[self.grid syncScene:NO];
    self.window.alphaValue=LPReduceMotion()?1:0;
    [NSApp activateIgnoringOtherApps:YES];[self.window makeKeyAndOrderFront:nil];[self.window makeFirstResponder:self.grid];
    if(!LPReduceMotion()){
        self.window.alphaValue=0;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){context.duration=.22;self.window.animator.alphaValue=1;}completionHandler:nil];
        LPAnimate(self.grid.rootViewport,@"transform.scale",@1.045,@1,.26);
        LPAnimate(self.grid.rootViewport,@"opacity",@0,@1,.22);
    }
}
- (void)dismiss {
    self.opening=NO;
    self.grid.dragging=NO;self.grid.dragItem=nil;[self.grid.holdTimer invalidate];[self.grid.edgeTimer invalidate];self.grid.holdTimer=nil;self.grid.edgeTimer=nil;
    if(self.closing)return;
    if(!self.window.visible||LPReduceMotion()){[self.window orderOut:nil];return;}
    self.closing=YES;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){context.duration=.18;self.window.animator.alphaValue=0;}
        completionHandler:^{if(self.closing){[self.window orderOut:nil];self.closing=NO;}}];
}
- (void)windowDidResignKey:(NSNotification *)notification {if(notification.object==self.window&&!self.grid.externalDragging&&!self.presentingDialog&&!NSApp.modalWindow)[self dismiss];}
- (NSModalResponse)runAlert:(NSAlert *)alert {
    self.presentingDialog=YES;
    alert.window.level=self.window.visible?self.window.level+1:NSModalPanelWindowLevel;
    [NSApp activateIgnoringOtherApps:YES];
    NSModalResponse response=[alert runModal];
    self.presentingDialog=NO;
    if(self.window.visible){[self.window makeKeyAndOrderFront:nil];[self.window makeFirstResponder:self.grid];}
    return response;
}
- (void)saveFrame:(NSString *)path presentation:(BOOL)presentation {
    NSWindow *capture=self.settingsWindow.visible?self.settingsWindow:self.window;
    if(presentation){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CGImageRef frame=CGWindowListCreateImage(CGRectNull,kCGWindowListOptionIncludingWindow,(CGWindowID)capture.windowNumber,kCGWindowImageBoundsIgnoreFraming|kCGWindowImageBestResolution);
#pragma clang diagnostic pop
        if(frame){NSBitmapImageRep *image=[[NSBitmapImageRep alloc]initWithCGImage:frame];CGImageRelease(frame);
            [[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}]writeToFile:path atomically:YES];return;}
    }
    NSView *view=capture.contentView;
    [view layoutSubtreeIfNeeded];[view displayIfNeeded];
    [self.search displayIfNeeded];[self.folderName displayIfNeeded];[view.layer displayIfNeeded];
    CGFloat scale=2;NSSize size=view.bounds.size;
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:ceil(size.width*scale) pixelsHigh:ceil(size.height*scale)
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    CGContextRef context=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep].CGContext;
    CGContextTranslateCTM(context,0,rep.pixelsHigh);CGContextScaleCTM(context,scale,-scale);
    CALayer *layer=presentation?(view.layer.presentationLayer?:view.layer):view.layer;
    [layer renderInContext:context];
    NSData *png=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if(![png writeToFile:path atomically:YES])NSLog(@"Preview write failed");
}
- (void)writePreview {
    [self.grid syncScene:NO];[self saveFrame:self.previewPath presentation:NO];[NSApp terminate:nil];
}
- (void)checkSettings {
    [self.settingsButton performClick:nil];
    BOOL opened=self.settingsWindow.visible;
    fprintf(stderr,"Visible Settings button opens panel: %s\n",opened?"PASS":"FAIL");
    if(!opened)exit(11);
    UInt16 originalCode=self.shortcutCode;UInt32 originalMods=self.shortcutModifiers;NSString *originalName=self.shortcutName;
    [self recordShortcut:nil];
    NSEvent *key=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
        modifierFlags:NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift timestamp:0
        windowNumber:self.settingsWindow.windowNumber context:nil characters:@" "charactersIgnoringModifiers:@" "isARepeat:NO keyCode:kVK_Space];
    [self recordShortcutEvent:key persist:NO];
    BOOL registered=!self.recordingShortcut&&self.hotkey&&self.shortcutModifiers==(controlKey|optionKey|shiftKey);
    fprintf(stderr,"Shortcut recording / Carbon registration: %s\n",registered?"PASS":"FAIL");
    if(!registered)exit(8);
    [self recordShortcut:nil];
    NSEvent *escape=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0
        windowNumber:self.settingsWindow.windowNumber context:nil characters:@"\x1b"charactersIgnoringModifiers:@"\x1b"isARepeat:NO keyCode:kVK_Escape];
    [self recordShortcutEvent:escape persist:NO];
    if(self.recordingShortcut||!self.hotkey)exit(9);
    [self registerShortcut:originalCode modifiers:originalMods name:originalName persist:NO];
    BOOL belowDock=self.window.level<CGWindowLevelForKey(kCGDockWindowLevelKey);
    fprintf(stderr,"Panel below Dock: %s (%ld < %d)\n",belowDock?"PASS":"FAIL",(long)self.window.level,CGWindowLevelForKey(kCGDockWindowLevelKey));
    if(!belowDock)exit(10);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self saveFrame:self.previewPath presentation:YES];[NSApp terminate:nil];});
}
- (void)checkSearch {
    [NSApp activateIgnoringOtherApps:YES];[self.window makeKeyAndOrderFront:nil];
    self.search.stringValue=@"Safari 中文";[self.window makeFirstResponder:self.search];
    NSTextView *editor=(NSTextView *)self.search.currentEditor;
    NSEvent *select=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand
        timestamp:0 windowNumber:self.window.windowNumber context:nil characters:@"a" charactersIgnoringModifiers:@"a" isARepeat:NO keyCode:0];
    BOOL consumed=[self filterKeyEvent:select]==nil;
    NSRange selection=editor.selectedRange;
    BOOL passed=editor&&consumed&&selection.location==0&&selection.length==self.search.stringValue.length;
    fprintf(stderr,"Search Command+A: %s (%lu of %lu characters)\n",passed?"PASS":"FAIL",(unsigned long)selection.length,(unsigned long)self.search.stringValue.length);
    if(!passed)exit(6);
    NSInteger originalPage=self.grid.page;
    NSEvent *nextPage=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand
        timestamp:0 windowNumber:self.window.windowNumber context:nil characters:@"\uF703" charactersIgnoringModifiers:@"\uF703" isARepeat:NO keyCode:kVK_RightArrow];
    BOOL pageConsumed=[self filterKeyEvent:nextPage]==nil;
    BOOL pagePassed=pageConsumed&&self.grid.page==MIN(originalPage+1,[self.grid pageCount]-1)&&NSEqualRanges(editor.selectedRange,selection);
    fprintf(stderr,"Search Command+Right pagination: %s\n",pagePassed?"PASS":"FAIL");
    if(!pagePassed)exit(12);
    [self.grid changePage:originalPage-self.grid.page];
    [self.searchBox layout];
    NSRect text=self.search.frame,icon=self.searchBox.icon.frame;
    NSRect editorRect=[editor convertRect:editor.bounds toView:self.searchBox];
    fprintf(stderr,"Search centers: field %.1f, icon %.1f, editor %.1f; editor x %.1f, field x %.1f\n",NSMidY(text),NSMidY(icon),NSMidY(editorRect),NSMinX(editorRect),NSMinX(text));
    if(fabs(NSMidY(text)-NSMidY(icon))>1||fabs(NSMidY(editorRect)-NSMidY(icon))>2||NSMinX(editorRect)<NSMaxX(icon)+4)exit(7);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        [self saveFrame:[self.previewPath.stringByDeletingPathExtension stringByAppendingString:@"-input.png"]presentation:YES];
        [self.window makeFirstResponder:self.grid];[self clearSearch:nil];[self.searchBox layout];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,150*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            [self saveFrame:self.previewPath presentation:YES];[NSApp terminate:nil];
        });
    });
}
- (void)checkMotion {
    [self.window orderFront:nil];[self.grid syncScene:NO];[self.background displayIfNeeded];
    NSString *directory=self.previewPath.stringByDeletingLastPathComponent;
    NSString *folder=NSProcessInfo.processInfo.environment[@"LP_PREVIEW_FOLDER"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        [self saveFrame:[directory stringByAppendingPathComponent:@"live-main.png"]presentation:YES];
        [self.grid changePage:1];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            CGFloat x=self.grid.rootStrip.presentationLayer.position.x,w=self.grid.rootViewport.bounds.size.width;
            BOOL moving=self.grid.rootStrip.presentationLayer&&x<0&&x>-w;
            fprintf(stderr,"Page intermediate position: %.1f / %.1f; %s\n",x,w,moving?"PASS":"FAIL");
            if(!moving)exit(2);
            [self saveFrame:[directory stringByAppendingPathComponent:@"page-mid.png"] presentation:YES];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            [self.grid changePage:-1];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                [self.grid openFolder:folder];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                    CALayer *layer=self.grid.folderSurface.layer.presentationLayer;
                    double scale=[[layer valueForKeyPath:@"transform.scale"]doubleValue];
                    fprintf(stderr,"Folder intermediate scale: %.3f; %s\n",scale,layer&&scale>.16&&scale<1?"PASS":"FAIL");
                    if(!layer||scale<=.16||scale>=1)exit(3);
                    [self saveFrame:[directory stringByAppendingPathComponent:@"folder-mid.png"] presentation:YES];
                });
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                    [self saveFrame:[directory stringByAppendingPathComponent:@"folder-end.png"] presentation:YES];
                    [self.grid closeFolder];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                        CALayer *layer=self.grid.folderSurface.layer.presentationLayer;
                        double scale=[[layer valueForKeyPath:@"transform.scale"]doubleValue];
                        fprintf(stderr,"Folder closing scale: %.3f; %s\n",scale,layer&&scale>.16&&scale<1?"PASS":"FAIL");
                        if(!layer||scale<=.16||scale>=1)exit(4);
                        [self saveFrame:[directory stringByAppendingPathComponent:@"folder-close-mid.png"] presentation:YES];
                    });
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                        NSDictionary *source=self.grid.rootItems[1],*target=self.grid.rootItems[2];
                        CALayer *old=self.grid.rootIcons[target[@"id"]];
                        lp_diagnostic_group([source[@"id"]UTF8String],[target[@"id"]UTF8String]);
                        self.grid.animateLayout=YES;[self.grid reload];self.grid.animateLayout=NO;
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                            CALayer *layer=old.presentationLayer;double scale=[[layer valueForKeyPath:@"transform.scale"]doubleValue];
                            fprintf(stderr,"Merge intermediate scale: %.3f; %s\n",scale,layer&&scale>.18&&scale<1?"PASS":"FAIL");
                            if(!layer||scale<=.18||scale>=1)exit(5);
                            [self saveFrame:[directory stringByAppendingPathComponent:@"merge-mid.png"]presentation:YES];
                        });
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[NSApp terminate:nil];});
                    });
                });
            });
        });
    });
}
- (void)refresh {
    if(self.scanning)return;self.scanning=YES;[self.grid setNeedsDisplay:YES];
    NSSet *cached=[NSSet setWithArray:self.grid.icons.allKeys];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        lp_refresh();
        NSMutableSet *paths=[NSMutableSet set];
        for(NSDictionary *item in Items(@"",@"")){
            [paths addObjectsFromArray:item[@"paths"]];
            if([item[@"count"]integerValue]>1)for(NSDictionary *child in Items(@"",item[@"id"]))[paths addObjectsFromArray:child[@"paths"]];
        }
        NSMutableDictionary *icons=[NSMutableDictionary dictionary];
        for(NSString *path in paths)if(![cached containsObject:path])icons[path]=LPRasterIcon(path);
        dispatch_async(dispatch_get_main_queue(),^{
            self.scanning=NO;[self.grid.icons addEntriesFromDictionary:icons];[self.grid reload];
            if(self.previewPath.length){
                NSString *folder=NSProcessInfo.processInfo.environment[@"LP_PREVIEW_FOLDER"];
                BOOL motion=NSProcessInfo.processInfo.environment[@"LP_MOTION_CHECK"].boolValue;
                if(folder.length&&!motion)[self.grid openFolder:folder];
                if(NSProcessInfo.processInfo.environment[@"LP_SETTINGS_CHECK"].boolValue)[self checkSettings];else if(NSProcessInfo.processInfo.environment[@"LP_SEARCH_CHECK"].boolValue)[self checkSearch];else if(motion)[self checkMotion];else[self writePreview];
            }
        });
    });
}
- (void)trashApplication:(NSURL *)url {
    if(!url.isFileURL||![url.pathExtension.lowercaseString isEqual:@"app"])return;
    [NSWorkspace.sharedWorkspace recycleURLs:@[url]completionHandler:^(NSDictionary<NSURL *,NSURL *> *locations,NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            if(error){NSAlert *alert=[NSAlert new];alert.messageText=@"无法移到废纸篓";alert.informativeText=error.localizedDescription;[self runAlert:alert];}
            [self refresh];
        });
    }];
}
- (void)restore {lp_action(5,"","",0);[self.grid reload];}
- (void)clearSearch:(id)sender {
    self.search.currentEditor.string=@"";self.search.stringValue=@"";
    [self controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:self.search]];
    [self.window makeFirstResponder:self.search];
}
- (void)controlTextDidChange:(NSNotification *)notification {
    if(notification.object==self.search){[self.searchBox setNeedsLayout:YES];self.grid.folder=@"";self.grid.page=0;self.grid.selected=0;[self.grid reload];}
}
- (void)controlTextDidEndEditing:(NSNotification *)notification {if(notification.object==self.folderName && self.grid.folder.length){lp_action(2,self.grid.folder.UTF8String,self.folderName.stringValue.UTF8String,0);[self.grid reload];}}
- (void)launch:(NSDictionary *)item {
    if([item[@"count"]integerValue]>1){self.search.stringValue=@"";[self.grid openFolder:item[@"id"]];[self.window makeFirstResponder:self.grid];return;}
    NSString *path=[item[@"paths"]firstObject];if(!path)return;
    NSWorkspaceOpenConfiguration *config=[NSWorkspaceOpenConfiguration configuration];
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:path] configuration:config completionHandler:^(NSRunningApplication *app,NSError *error){if(error){dispatch_async(dispatch_get_main_queue(),^{NSAlert *alert=[NSAlert new];alert.messageText=@"无法打开应用";alert.informativeText=error.localizedDescription;[alert runModal];});}}];
    [self dismiss];
}
- (void)help {
    NSAlert *alert=[NSAlert new];alert.messageText=@"Launchpad2";
    alert.informativeText=@"⌃⌥Space：全局打开 / 收起\n直接输入：搜索（含文件夹中的应用）\n方向键选择，Return 打开，⌘← / → 翻页\nEsc：退出搜索、文件夹或整理模式，再收起\n触控板双指滑动翻页，展开捏合收起\n按住或右键整理，拖到图标中心建文件夹\n拖到图标旁边排序；两侧停留翻页\n点击文件夹标题重命名，拖出面板移出应用\n右键应用可隐藏或在 Finder 显示\n\n系统四指捏合请通过 BetterTouchTool 等工具绑定到打开 Launchpad2.app，或 launchpad2://open。公开 API 不提供系统级四指手势替换。";
    [self runAlert:alert];
}
- (void)quit {[NSApp terminate:nil];}
- (void)applicationWillTerminate:(NSNotification *)notification {lp_gesture_stop();[self.settingsTimer invalidate];if(self.hotkey)UnregisterEventHotKey(self.hotkey);if(self.hotkeyHandler)RemoveEventHandler(self.hotkeyHandler);if(self.localMonitor)[NSEvent removeMonitor:self.localMonitor];}
@end
void lp_run(void){@autoreleasepool{NSApplication *app=NSApplication.sharedApplication;__attribute__((objc_precise_lifetime)) LPController *controller=[LPController new];app.delegate=controller;[app run];}}
