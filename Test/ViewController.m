//
//  ViewController.m
//  Test
//
//  Created by Maria Elena Villamil on 12/8/14.
//  Copyright (c) 2014 Maria Elena Villamil. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation ViewController

AVCaptureSession * session;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self._eyes = false;
    self._count = 0;
    
    [self setupCaptureSession];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Create and configure a capture session and start it running
- (void)setupCaptureSession
{
    NSError *error = nil;
    
    // Create the session
    session = [[AVCaptureSession alloc] init];
    
    // Configure the session to produce lower resolution video frames, if your
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
    session.sessionPreset = AVCaptureSessionPresetMedium;
    
    // Find a suitable AVCaptureDevice
    AVCaptureDevice *device = nil;
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *d in devices) {
        if ([d position] == AVCaptureDevicePositionFront) {
            device = d;
        }
    }
    
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                        error:&error];
    if (!input) {
        NSLog(@"Couldn't connect to the front camera");
        return;
    }
    
    [session addInput:input];

    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [session addOutput:output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    //dispatch_release(queue);
    
    // Specify the pixel format
    output.videoSettings =
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    
    // If you wish to cap the frame rate to a known value, such as 15 fps, set
    // minFrameDuration.
    //output.minFrameDuration = CMTimeMake(1, 15);
    
    // Start the session running to start the flow of data
    [session startRunning];
}

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // Create a UIImage from the sample buffer data
    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
    
    //////////////////////
    
    UIView* window = ([UIApplication sharedApplication].delegate).window;
    EAGLContext *eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    GLKView *videoPreviewView =[[GLKView alloc] initWithFrame:window.bounds context:eaglContext];
    videoPreviewView.enableSetNeedsDisplay = NO;
    
    // because the native video image from the back camera is in UIDeviceOrientationLandscapeLeft (i.e. the home button is on the right), we need to apply a clockwise 90 degree transform so that we can draw the video preview as if we were in a landscape-oriented view; if you're using the front camera and you want to have a mirrored preview (so that the user is seeing themselves in the mirror), you need to apply an additional horizontal flip (by concatenating CGAffineTransformMakeScale(-1.0, 1.0) to the rotation transform)
    CGAffineTransform transform = CGAffineTransformMakeRotation(M_PI_2);
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(-1.0, 1.0));
    
    videoPreviewView.transform = transform;
    videoPreviewView.frame = window.bounds;

    CIContext* ci_context = [CIContext contextWithEAGLContext:eaglContext options:@{kCIContextWorkingColorSpace : [NSNull null]} ];
    
    //////////////////////
    
    NSDictionary *opts = [NSDictionary dictionaryWithObjectsAndKeys:
                          CIDetectorImageOrientation,
                          [self ciOrientationFromDeviceOrientation:[UIApplication sharedApplication].statusBarOrientation],
                          [NSNumber numberWithBool:YES],
                          CIDetectorEyeBlink,
                          [NSNumber numberWithBool:YES],
                          CIDetectorSmile,
                          nil];
    
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace context:ci_context options:opts];
    
    
    NSArray* features = [detector featuresInImage:image.CIImage options:opts];
    
    for (CIFaceFeature *f in features)
    {
        NSLog(@"Features not empty");
        if (f.leftEyeClosed && f.rightEyeClosed)
        {
            self._eyes = true;
            
            if (self._count > 2)
                NSLog(@"Eyes are closed");
        }
        
        else
        {
            self._eyes = false;
            self._count = 0;
            NSLog(@"Eyes are open");
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.image_view setImage:image];
    });
    
    //< Add your code here that uses the image >
    
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}


// eric's function
-(NSNumber *)ciOrientationFromDeviceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    NSNumber *ciOrientation = @1;
    
    if(interfaceOrientation == UIInterfaceOrientationPortrait){
        ciOrientation = @5;
    }
    else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown){
        ciOrientation = @7;
    }
    else if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft){
        ciOrientation = @1;
    }
    else if(interfaceOrientation == UIInterfaceOrientationLandscapeRight){
        ciOrientation = @3;
    }
    else{
        //unknown orientation!
    }
    
    return ciOrientation;
}


@end
