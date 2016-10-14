//
//  MCPanelViewController.m
//  MCPanelViewController
//
//  Created by Matthew Cheok on 2/10/13.
//  Copyright (c) 2013 Matthew Cheok. All rights reserved.
//

#import "MCPanelViewController.h"
#import "MCPanGestureRecognizer.h"

#import "UIImage+ImageEffects.h"
#import "UIView+MCAdditions.h"

#import <objc/runtime.h>

// constants
const static CGFloat MCPanelViewAnimationDuration = 0.3;
const static CGFloat MCPanelViewGestureThreshold = 0.6;
const static CGFloat MCPanelViewUndersampling = 4;

// associative references on UIScreenEdgePanGestureRecognizer to remember some information we need later
const static NSString *MCPanelViewGesturePresentingViewControllerKey = @"MCPanelViewGesturePresentingViewControllerKey";
const static NSString *MCPanelViewGesturePresentedViewControllerKey = @"MCPanelViewGesturePresentedViewControllerKey";
const static NSString *MCPanelViewGestureAnimationDirectionKey = @"MCPanelViewGestureAnimationDirectionKey";

@interface UIViewController (MCPanelViewControllerInternal) <UIGestureRecognizerDelegate>

- (void)addToParentViewController:(UIViewController *)parentViewController inView:(UIView *)view callingAppearanceMethods:(BOOL)callAppearanceMethods;
- (void)removeFromParentViewControllerCallingAppearanceMethods:(BOOL)callAppearanceMethods;

@end

@implementation UIViewController (MCPanelViewControllerInternal)

- (void)addToParentViewController:(UIViewController *)parentViewController inView:(UIView *)view callingAppearanceMethods:(BOOL)callAppearanceMethods {
    if (self.parentViewController != nil) {
        [self removeFromParentViewControllerCallingAppearanceMethods:callAppearanceMethods];
    }

    if (callAppearanceMethods)
        [self beginAppearanceTransition:YES animated:NO];
    [parentViewController addChildViewController:self];
    [view addSubview:self.view];
    [self didMoveToParentViewController:self];
    if (callAppearanceMethods)
        [self endAppearanceTransition];
}

- (void)removeFromParentViewControllerCallingAppearanceMethods:(BOOL)callAppearanceMethods {
    if (callAppearanceMethods)
        [self beginAppearanceTransition:NO animated:NO];
    [self willMoveToParentViewController:nil];
    [self.view removeFromSuperview];
    [self removeFromParentViewController];
    if (callAppearanceMethods)
        [self endAppearanceTransition];
}

@end


@interface MCPanelViewController () <UIGestureRecognizerDelegate>

@property (assign, nonatomic) MCPanelAnimationDirection direction;
@property (assign, nonatomic) CGFloat maxWidth;
@property (assign, nonatomic) CGFloat maxHeight;

@property (strong, nonatomic) UIView *shadowView;
@property (strong, nonatomic) UIView *imageViewContainer;
@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UIButton *backgroundButton;
@property (strong, nonatomic) MCPanGestureRecognizer *panGestureRecognizer;

// presentedViewController
@property (strong, nonatomic, readwrite) UIViewController *rootViewController;

@end


@implementation MCPanelViewController

- (id)initWithRootViewController:(UIViewController *)controller {
    self = [super init];
    if (self) {
        self.tintColor = [UIColor colorWithWhite:1.0 alpha:0.3];
        self.maskColor = [UIColor colorWithWhite:0 alpha:0.5];
        self.shadowColor = [UIColor blackColor];
        self.shadowOpacity = 0.3;
        self.shadowRadius = 5;
        self.rootViewController = controller;
        if ([controller isKindOfClass:[UINavigationController class]]) {
            UINavigationController *navController = (UINavigationController *)controller;
            navController.topViewController.view.backgroundColor = [UIColor clearColor];
        }
        else {
            controller.view.backgroundColor = [UIColor clearColor];
        }

        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    UIViewAutoresizing fullScreenMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.autoresizingMask = fullScreenMask;

    self.backgroundButton = [[UIButton alloc] init];
    self.backgroundButton.autoresizingMask = fullScreenMask;
    [self.backgroundButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    self.masking = YES;

    [self.view addSubview:self.backgroundButton];

    self.shadowView = [[UIView alloc] init];

    self.imageView = [[UIImageView alloc] init];
    self.imageView.clipsToBounds = YES;

    self.imageViewContainer = [[UIView alloc] init];
    self.imageViewContainer.clipsToBounds = YES;
    self.imageViewContainer.backgroundColor = [UIColor clearColor];
    [self.imageViewContainer addSubview:self.imageView];

    [self.view addSubview:self.shadowView];
    [self.view addSubview:self.imageViewContainer];

    [self setPanningEnabled:YES];
}

- (void)setPanningEnabled:(BOOL)panningEnabled {
    if (panningEnabled == _panningEnabled) {
        return;
    }

    _panningEnabled = panningEnabled;

    if (panningEnabled && !self.panGestureRecognizer) {
        self.panGestureRecognizer = [[MCPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        self.panGestureRecognizer.direction = MCPanGestureRecognizerDirectionHorizontal;
        self.panGestureRecognizer.delegate = self;
        [self.rootViewController.view addGestureRecognizer:self.panGestureRecognizer];
    }
    else if (!panningEnabled && self.panGestureRecognizer) {
        [self.rootViewController.view removeGestureRecognizer:self.panGestureRecognizer];
        self.panGestureRecognizer = nil;
    }
}

- (void)layoutSubviewsToWidth:(CGFloat)width {
    CGRect bounds = self.parentViewController.view.bounds;
    width = MIN(width, self.maxWidth);

    CGFloat offset = 0;
    CGRect frame = CGRectZero;
    if (self.direction == MCPanelAnimationDirectionLeft) {
        frame = CGRectMake(width - self.maxWidth, 0, self.maxWidth, self.maxHeight);
    }
    else {
        offset = CGRectGetWidth(bounds) - width;
        frame = CGRectMake(CGRectGetWidth(bounds) - width, 0, self.maxWidth, self.maxHeight);
    }

    self.backgroundButton.alpha = width / self.maxWidth;
    self.imageViewContainer.frame = CGRectMake(offset, 0, width, self.maxHeight);
    self.imageView.frame = CGRectMake(_direction == MCPanelAnimationDirectionLeft ? 0 : _imageViewContainer.bounds.size.width - bounds.size.width, 0, self.imageView.image.size.width * MCPanelViewUndersampling, self.imageView.image.size.height * MCPanelViewUndersampling);
    self.shadowView.frame = frame;
    self.rootViewController.view.frame = frame;

}

- (void)viewIsAppearingWithProgress:(CGFloat)progress
{
    progress = MIN(MAX(0, progress), 1);
    if ([self.rootViewController respondsToSelector:@selector(viewIsAppearingWithProgress:)])
    {
        [self.rootViewController performSelector:@selector(viewIsAppearingWithProgress:) withObject:@(progress)];
    }
}

- (void)viewIsDisappearingWithProgress:(CGFloat)progress
{
    progress = MIN(MAX(0, progress), 1);
    if ([self.rootViewController respondsToSelector:@selector(viewIsDisappearingWithProgress:)])
    {
        [self.rootViewController performSelector:@selector(viewIsDisappearingWithProgress:) withObject:@(progress)];
    }
}

- (void)setupController:(UIViewController *)controller withDirection:(MCPanelAnimationDirection)direction {
    self.direction = direction;

    CGRect bounds = controller.view.bounds;
    self.maxHeight = CGRectGetHeight(bounds);
    self.maxWidth = self.rootViewController.preferredContentSize.width;
    if (self.maxWidth == 0) {
        self.maxWidth = 320;
    }

    [self.rootViewController addToParentViewController:self inView:self.view callingAppearanceMethods:NO];

    self.view.frame = bounds;
    self.backgroundButton.frame = bounds;

    // support rotation
    UIViewAutoresizing mask = UIViewAutoresizingFlexibleHeight;
    switch (direction) {
        case MCPanelAnimationDirectionLeft:
            mask |= UIViewAutoresizingFlexibleRightMargin;
            break;

        case MCPanelAnimationDirectionRight:
            mask |= UIViewAutoresizingFlexibleLeftMargin;
            break;

        default:
            break;
    }

    self.rootViewController.view.autoresizingMask = mask;
    self.imageViewContainer.autoresizingMask = mask;
    self.shadowView.autoresizingMask = mask;
    [self addToParentViewController:controller inView:controller.view callingAppearanceMethods:NO];

    [self refreshBackgroundAnimated:NO];
    //	self.imageView.contentMode = (UIViewContentMode)direction;

    //Masking appearance
    if (self.masking) {
        self.backgroundButton.backgroundColor = self.maskColor;
    }
    else {
        self.backgroundButton.backgroundColor = [UIColor clearColor];
    }

    //Shadow appearance
    self.shadowView.layer.shadowColor = self.shadowColor.CGColor;
    self.shadowView.layer.shadowOpacity = self.shadowOpacity;
    self.shadowView.layer.shadowRadius = self.shadowRadius;
    self.shadowView.layer.shadowOffset = CGSizeZero;
    self.shadowView.layer.shadowPath = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, self.maxWidth, self.maxHeight)].CGPath;
}

- (void)presentInViewController:(UIViewController *)controller withDirection:(MCPanelAnimationDirection)direction {
    [self setupController:controller withDirection:direction];
    [self layoutSubviewsToWidth:0];

    __weak typeof(self) weakSelf = self;

    [UIView animateWithDuration:MCPanelViewAnimationDuration delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        typeof(self) strongSelf = weakSelf;
        [strongSelf layoutSubviewsToWidth:strongSelf.maxWidth];
    } completion: ^(BOOL finished) {
    }];
}

- (void)viewWillDisappearIn:(NSTimeInterval)duration
{
    if ([self.rootViewController respondsToSelector:@selector(viewWillDisappearIn:)])
    {
        [self.rootViewController performSelector:@selector(viewWillDisappearIn:) withObject:@(duration)];
    }
}

- (void)dismiss {
    CGRect bounds = self.parentViewController.view.bounds;

    CGFloat currentWidth = CGRectGetMinX(self.rootViewController.view.frame);
    if (self.direction == MCPanelAnimationDirectionLeft) {
        currentWidth += self.maxWidth;
    }
    else {
        currentWidth = CGRectGetWidth(bounds) - currentWidth;
    }
    CGFloat ratio = currentWidth / self.maxWidth;

    __weak typeof(self) weakSelf = self;
    NSTimeInterval duration = MCPanelViewAnimationDuration * ratio;
    [self viewWillDisappearIn:duration];
    [UIView animateWithDuration:duration delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        typeof(self) strongSelf = weakSelf;
        [strongSelf layoutSubviewsToWidth:0];
    } completion: ^(BOOL finished) {
        typeof(self) strongSelf = weakSelf;
        [self.rootViewController removeFromParentViewControllerCallingAppearanceMethods:YES];
        [strongSelf removeFromParentViewControllerCallingAppearanceMethods:YES];
    }];
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    [super willMoveToParentViewController:parent];
    if (parent) {
        if ([self.delegate respondsToSelector:@selector(willPresentPanelViewController:)]) {
            [self.delegate willPresentPanelViewController:self];
        }
    }
    else {
        if ([self.delegate respondsToSelector:@selector(willDismissPanelViewController:)]) {
            [self.delegate willDismissPanelViewController:self];
        }
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    [super didMoveToParentViewController:parent];
    if (parent) {
        if ([self.delegate respondsToSelector:@selector(didPresentPanelViewController:)]) {
            [self.delegate didPresentPanelViewController:self];
        }
    }
    else {
        if ([self.delegate respondsToSelector:@selector(didDismissPanelViewController:)]) {
            [self.delegate didDismissPanelViewController:self];
        }
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    CGRect bounds = self.parentViewController.view.bounds;
    self.maxHeight = CGRectGetHeight(bounds);

    [self refreshBackgroundAnimated:YES];
}

- (void)refreshBackgroundAnimated:(BOOL)animated {
    UIView *view = self.parentViewController.view;

    //    BOOL wasViewAttached = (self.view.superview != nil);
    //    if (wasViewAttached) {
    //        [self.view removeFromSuperview];
    //    }
    self.view.hidden = YES;

    // extend background image height to the longer of the dimensions
    // so that when rotating the background is seamless
    CGFloat width = CGRectGetWidth(view.bounds);
    CGFloat height = CGRectGetHeight(view.bounds);
    CGFloat dimension = MAX(width, height);
    CGRect rect = CGRectMake(0, 0, width, dimension);
    CGRect undersampledRect = CGRectApplyAffineTransform(rect, CGAffineTransformMakeScale(1 / MCPanelViewUndersampling, 1 / MCPanelViewUndersampling));

    // get snapshot image
    UIGraphicsBeginImageContextWithOptions(undersampledRect.size, NO, 0.0);

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(ctx, 1 / MCPanelViewUndersampling, 1 / MCPanelViewUndersampling);

    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];

    // try to extend image by reflecting
    if (rect.size.height > height) {
        CGContextTranslateCTM(ctx, 0, 2 * height);
        CGContextScaleCTM(ctx, 1, -1);
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        CGContextClipToRect(ctx, view.bounds);
        [image drawInRect:CGRectMake(0, 0, rect.size.width, rect.size.height)];
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    switch (self.backgroundStyle) {
        case MCPanelBackgroundStyleExtraLight:
            image = [image applyExtraLightEffect];
            break;

        case MCPanelBackgroundStyleDark:
            image = [image applyDarkEffect];
            break;

        case MCPanelBackgroundStyleTinted:
            image = [image applyTintEffectWithColor:self.tintColor];
            break;

        default:
            image = [image applyLightEffect];
            break;
    }

    //    if (wasViewAttached) {
    //        [view addSubview:self.view];
    //    }
    self.view.hidden = NO;

    if (animated) {
        __weak typeof(self) weakSelf = self;

        [UIView transitionWithView:self.imageView
                          duration:MCPanelViewAnimationDuration
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                        animations: ^{
                            typeof(self) strongSelf = weakSelf;
                            strongSelf.imageView.image = image;
                            strongSelf.imageView.frame = CGRectMake(_direction == MCPanelAnimationDirectionLeft ? 0 : _imageViewContainer.bounds.size.width - width, 0, image.size.width * MCPanelViewUndersampling, image.size.height * MCPanelViewUndersampling);
                        } completion:nil];
    }
    else {
        self.imageView.image = image;
        self.imageView.frame = CGRectMake(_direction == MCPanelAnimationDirectionLeft ? 0 : _imageViewContainer.bounds.size.width - width, 0, image.size.width * MCPanelViewUndersampling, image.size.height * MCPanelViewUndersampling);
    }
}

#pragma mark - Gestures

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([[gestureRecognizer.view hitTest:[touch locationInView:gestureRecognizer.view] withEvent:nil] isKindOfClass:[UIControl class]]) {
        return NO;
    }
    return YES;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    // initialization for screen edge pan gesture
    MCPanelAnimationDirection direction = [objc_getAssociatedObject(pan, &MCPanelViewGestureAnimationDirectionKey) integerValue];
    if ([pan isKindOfClass:[UIScreenEdgePanGestureRecognizer class]] &&
        pan.state == UIGestureRecognizerStateBegan) {
        __weak UIViewController *controller = objc_getAssociatedObject(pan, &MCPanelViewGesturePresentingViewControllerKey);

        if (!controller) {
            return;
        }

        [self setupController:controller withDirection:direction];

        CGPoint translation = [pan translationInView:pan.view];
        CGFloat width = direction == MCPanelAnimationDirectionLeft ? translation.x : -1 * translation.x;

        [self layoutSubviewsToWidth:0];
        __weak typeof(self) weakSelf = self;

        [UIView animateWithDuration:MCPanelViewAnimationDuration delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0 options:0 animations:^{
            typeof(self) strongSelf = weakSelf;
            [strongSelf layoutSubviewsToWidth:width];
        } completion:nil];

        CGFloat offset = self.maxWidth - width;
        if (direction == MCPanelAnimationDirectionLeft) {
            offset *= -1;
        }
        [pan setTranslation:CGPointMake(offset, translation.y) inView:pan.view];
    }

    if (!self.parentViewController) {
        return;
    }

    CGFloat newWidth = [pan translationInView:pan.view].x;
    if (self.direction == MCPanelAnimationDirectionRight) {
        newWidth *= -1;
    }
    newWidth += self.maxWidth;
    CGFloat ratio = newWidth / self.maxWidth;

    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged: {
            //			if (newWidth <= self.maxWidth) {
            [self layoutSubviewsToWidth:newWidth];
            //			}
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat threshold = MCPanelViewGestureThreshold;

            // invert threshold if we started a screen edge pan gesture
            if ([pan isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
                threshold = 1 - threshold;
            }

            if (ratio < threshold) {
                [self dismiss];
                ratio = 0;
            }
            else {
                __weak typeof(self) weakSelf = self;

                [UIView animateWithDuration:MCPanelViewAnimationDuration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations: ^{
                    typeof(self) strongSelf = weakSelf;
                    [strongSelf layoutSubviewsToWidth:strongSelf.maxWidth];
                } completion: ^(BOOL finished) {
                }];
                ratio = 1;
            }
            break;
        }

        default:
            break;
    }
    CGPoint velocity = [pan velocityInView:self.view];
    if (velocity.x < 0)
    {
        direction = MCPanelAnimationDirectionLeft;
    }
    else
    {
        direction = MCPanelAnimationDirectionRight;
    }
    if (direction != self.direction)
    {
        [self viewIsAppearingWithProgress:ratio];
    }
    else
    {
        [self viewIsDisappearingWithProgress:1 - ratio];
    }
}

- (UIScreenEdgePanGestureRecognizer *)gestureRecognizerForScreenEdgeGestureInViewController:(UIViewController *)controller withDirection:(MCPanelAnimationDirection)direction {
    UIScreenEdgePanGestureRecognizer *pan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.edges = direction == MCPanelAnimationDirectionLeft ? UIRectEdgeLeft : UIRectEdgeRight;

    objc_setAssociatedObject(pan, &MCPanelViewGesturePresentingViewControllerKey,
                             controller, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(pan, &MCPanelViewGesturePresentedViewControllerKey,
                             self, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(pan, &MCPanelViewGestureAnimationDirectionKey,
                             @(direction), OBJC_ASSOCIATION_RETAIN);

    return pan;
}

- (void)removeGestureRecognizersForScreenEdgeGestureFromView:(UIView *)view {
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
            __weak UIViewController *controller = objc_getAssociatedObject(recognizer, &MCPanelViewGesturePresentedViewControllerKey);
            if (controller == self) {
                [view removeGestureRecognizer:recognizer];
            }
        }
    }
}

@end

@implementation UIViewController (MCPanelViewController)

- (MCPanelViewController *)viewControllerInPanelViewController {
    return [[MCPanelViewController alloc] initWithRootViewController:self];
}

- (MCPanelViewController *)panelViewController {
    UIViewController *parent = self.parentViewController;
    while (parent != nil && ![parent isKindOfClass:[MCPanelViewController class]]) {
        parent = parent.parentViewController;
    }
    return (id)parent;
}

- (void)presentPanelViewController:(MCPanelViewController *)controller withDirection:(MCPanelAnimationDirection)direction {
    [controller presentInViewController:self withDirection:direction];
}

- (void)addGestureRecognizerToViewForScreenEdgeGestureWithPanelViewController:(MCPanelViewController *)controller withDirection:(MCPanelAnimationDirection)direction {
    UIScreenEdgePanGestureRecognizer *pan = [controller gestureRecognizerForScreenEdgeGestureInViewController:self withDirection:direction];
    [self.view addGestureRecognizer:pan];
    
    NSArray *scrollViews = [self.view subviewsOfKindOfClass:[UIScrollView class]];
    for (UIScrollView *scrollView in scrollViews) {
        [scrollView.panGestureRecognizer requireGestureRecognizerToFail:pan];
    }
}

- (void)removeGestureRecognizersFromViewForScreenEdgeGestureWithPanelViewController:(MCPanelViewController *)controller {
    [controller removeGestureRecognizersForScreenEdgeGestureFromView:self.view];
}

@end
