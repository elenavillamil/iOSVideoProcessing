//
//  ViewController.h
//  Test
//
//  Created by Maria Elena Villamil on 12/8/14.
//  Copyright (c) 2014 Maria Elena Villamil. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <CoreImage/CoreImage.h>


@interface ViewController : UIViewController 

@property (weak, nonatomic) IBOutlet UIImageView *image_view;
@property NSDictionary *detectorOptions;
@property CIDetector *face_detector;
@property NSArray *features;
@property UIImage *image;
@property bool _eyes;
@property int _count;
@end

