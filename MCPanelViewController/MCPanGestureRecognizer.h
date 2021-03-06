//
//  MCPanGestureRecognizer.h
//  MCPanelViewController
//
//  Created by Matthew Cheok on 2/10/13.
//  Copyright (c) 2013 Matthew Cheok. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, MCPanGestureRecognizerDirection) {
    MCPanGestureRecognizerDirectionNone = 0,
    MCPanGestureRecognizerDirectionHorizontal,
    MCPanGestureRecognizerDirectionVertical
};

@protocol MCPanGestureRecognizerWithDirection <NSObject>

@required
@property (assign, nonatomic) MCPanGestureRecognizerDirection direction;

@end

@interface MCPanGestureRecognizer : UIPanGestureRecognizer <MCPanGestureRecognizerWithDirection>

@property (assign, nonatomic) MCPanGestureRecognizerDirection direction;

@end

