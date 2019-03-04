//
//  MCScreenEdgePanGestureRecognizer.h
//  MCPanelViewController
//
//  Created by Guillaume Algis on 04/03/2019.
//  Copyright (c) 2013 Matthew Cheok. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MCPanGestureRecognizer.h"

@interface MCScreenEdgePanGestureRecognizer : UIScreenEdgePanGestureRecognizer <MCPanGestureRecognizerWithDirection>

@property (weak, nonatomic) UIViewController *presentingViewController;
@property (weak, nonatomic) UIViewController *presentedViewController;
@property (assign, nonatomic) MCPanGestureRecognizerDirection direction;

@end

