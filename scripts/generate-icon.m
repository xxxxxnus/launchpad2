#import <AppKit/AppKit.h>
int main(int argc,const char **argv){@autoreleasepool{
    if(argc!=2)return 2;
    NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:1024 pixelsHigh:1024 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    NSBezierPath *base=[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(64,64,896,896) xRadius:204 yRadius:204];
    NSGradient *gradient=[[NSGradient alloc]initWithStartingColor:[NSColor colorWithWhite:.30 alpha:1] endingColor:[NSColor colorWithWhite:.12 alpha:1]];[gradient drawInBezierPath:base angle:90];
    CGFloat hue[]={.56,.62,.78,.46,.08,.98,.36,.14,.51};
    for(int row=0;row<3;row++)for(int col=0;col<3;col++){
        NSRect r=NSMakeRect(215+col*210,215+row*210,174,174);
        NSBezierPath *tile=[NSBezierPath bezierPathWithRoundedRect:r xRadius:39 yRadius:39];
        NSColor *color=[NSColor colorWithCalibratedHue:hue[row*3+col] saturation:.72 brightness:.96 alpha:1];
        NSGradient *g=[[NSGradient alloc]initWithStartingColor:color endingColor:[color blendedColorWithFraction:.15 ofColor:NSColor.whiteColor]];[g drawInBezierPath:tile angle:90];
        [[NSColor colorWithWhite:1 alpha:.2]setStroke];tile.lineWidth=2;[tile stroke];
    }
    NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];return [png writeToFile:@(argv[1]) atomically:YES]?0:1;
}}
