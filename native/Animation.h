static BOOL LPReduceMotion(void) {
    return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
}
static void LPAnimate(CALayer *layer, NSString *key, id from, id to, double duration) {
    if (LPReduceMotion() || duration <= 0) return;
    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:key];
    a.fromValue = from; a.toValue = to; a.duration = duration;
    a.timingFunction = [CAMediaTimingFunction functionWithControlPoints:.22 :.78 :.24 :1];
    [layer addAnimation:a forKey:key];
}
static void LPSpring(CALayer *layer, CGFloat from) {
    if (LPReduceMotion()) return;
    CASpringAnimation *a = [CASpringAnimation animationWithKeyPath:@"transform.scale"];
    a.fromValue = @(from); a.toValue = @1; a.mass = 1; a.stiffness = 260;
    a.damping = 22; a.initialVelocity = 0; a.duration = .38;
    [layer addAnimation:a forKey:@"arrival"];
}
static NSImage *LPRasterIcon(NSString *path) {
    @autoreleasepool {
        NSImage *original = [NSWorkspace.sharedWorkspace iconForFile:path];
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:192 pixelsHigh:192 bitsPerSample:8
            samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
            bytesPerRow:0 bitsPerPixel:0];
        rep.size = NSMakeSize(96,96);
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
        [original drawInRect:NSMakeRect(0,0,96,96) fromRect:NSZeroRect
            operation:NSCompositingOperationSourceOver fraction:1];
        [NSGraphicsContext restoreGraphicsState];
        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(96,96)];
        [image addRepresentation:rep];
        return image;
    }
}
