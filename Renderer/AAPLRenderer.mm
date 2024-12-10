// AAPLRenderer.mm

#include <MetalKit/MetalKit.h>;
#include "include/core/SkCanvas.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkColorType.h"
#include "include/core/SkSurface.h"
#include "include/gpu/GrBackendSurface.h"
#include "include/gpu/GrContextOptions.h"
#include "include/gpu/GrDirectContext.h"
#include "include/gpu/mtl/GrMtlTypes.h"
#include "include/core/SkStream.h"
#include "include/core/SkFont.h"
#include "include/codec/SkCodec.h"
#include "include/core/SkBitmap.h"
#include "include/encode/SkEncoder.h"
#include "include/effects/SkGradientShader.h"

#import "AAPLRenderer.h"


// Main class performing the rendering
@implementation AAPLRenderer
{
    id<MTLDevice> _device;
    
    GrDirectContext*    fDContext;

    // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
    id<MTLRenderPipelineState> _pipelineState;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;

    // The current size of the view, used as an input to the vertex shader.
    vector_uint2 _viewportSize;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        NSError *error;

        _device = mtkView.device;
                                       
        _commandQueue = [_device newCommandQueue];
        
        [mtkView setDepthStencilPixelFormat:MTLPixelFormatDepth32Float_Stencil8];
        [mtkView setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
        [mtkView setSampleCount:1];
        
        GrContextOptions grContextOptions;  // set different options here.
        fDContext = GrDirectContext::MakeMetal((__bridge void*)_device,
                                                              (__bridge void*)_commandQueue,grContextOptions).release();
        
    }

    return self;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Save the size of the drawable to pass to the vertex shader.
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

/// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{

    if (!fDContext ||
        MTLPixelFormatDepth32Float_Stencil8 != [view depthStencilPixelFormat] ||
        MTLPixelFormatBGRA8Unorm != [view colorPixelFormat]) {
        panic("no");
    }

    const SkColorType colorType = kBGRA_8888_SkColorType;  // MTLPixelFormatBGRA8Unorm
    sk_sp<SkColorSpace> colorSpace = nullptr;  // MTLPixelFormatBGRA8Unorm
    const GrSurfaceOrigin origin = kTopLeft_GrSurfaceOrigin;
    const SkSurfaceProps surfaceProps;
    int sampleCount = (int)[view sampleCount];

    sk_sp<SkSurface> surface = SkSurface::MakeFromMTKView(fDContext, (__bridge GrMTLHandle)view, origin, sampleCount,
                                          colorType, colorSpace, &surfaceProps);
    
    SkCanvas* canvas = surface.get()->getCanvas();
    canvas->translate(surface->width() * 0.5f, surface->height() * 0.5f);
    SkPaint paint;
    paint.setColor(SK_ColorBLUE);
    canvas->drawRect({10, 10, 100, 100}, paint);

    sk_sp<SkTypeface> typeface = SkTypeface::MakeFromName("PingFang SC", SkFontStyle());
    SkFont font = SkFont(typeface, 80);
    paint.setColor(SK_ColorWHITE);
    canvas->drawSimpleText("中国hello", 11, SkTextEncoding::kUTF8, 200, 200, font, paint);
    
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithUTF8String:"20240125-161941"] ofType:@"jpeg"];
    const char *filePath = [imagePath UTF8String];
    sk_sp<SkData> filedata = SkData::MakeFromFileName(filePath);
    
    sk_sp<SkImage> skimage = SkImage::MakeFromEncoded(filedata);
    canvas->drawImage(skimage.get(), -200, 300);

    sk_sp<SkTypeface> emojiface = SkTypeface::MakeFromName("Apple Color Emoji", SkFontStyle());
    SkFont emojifont = SkFont(emojiface, 80);
    SkGlyphID glyphid = 1275;
    SkPoint point = SkPoint::Make(-130, -20);
    canvas->drawGlyphs(1, &glyphid, &point, {0, 0}, emojifont, paint);
    
    surface->flushAndSubmit();
    surface = nullptr;
    ///
    ///
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    [commandBuffer presentDrawable:[view currentDrawable]];
    [commandBuffer commit];
}

@end
