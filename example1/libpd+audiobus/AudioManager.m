//
//  AudioManager.m
//  libpd+audiobus
//
//  Created by Ragnar Hrafnkelsson on 31/10/2013.
//  Copyright (c) 2013 Reactify. All rights reserved.
//

#import "AudioManager.h"
#import "Audiobus.h"
#import "PdBase.h"
#import "PdAudioController_AB.h"    // Make sure to import our extended PdAudioController


@interface AudioManager () {
    
    PdAudioController *pdAudioController_;
    
    ABInputPort *inputPort_;
    ABOutputPort *outputPort_;
}
@property (strong, nonatomic) ABAudiobusController *audiobusController;
@property (strong, nonatomic) ABAudiobusAudioUnitWrapper *audiobusAudioUnitWrapper;
@property (nonatomic, readwrite, getter = isActive) BOOL active;

@end



@implementation AudioManager

@synthesize audiobusController;
@synthesize audiobusAudioUnitWrapper;


+ (AudioManager *)sharedInstance
{
    static AudioManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AudioManager alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
    if (self = [super init]) {
        
        //Register for notifications
        [[NSNotificationCenter defaultCenter]addObserver:self
                                                selector:@selector(applicationWillEnterForeground:)
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self
                                                selector:@selector(applicationDidEnterBackground:)
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(connectionsChanged:)
                                                     name:ABConnectionsChangedNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)start
{
    if (self.isActive) {
        return;
    }
    
    [PdBase setDelegate: self];     // register for Pd messages
    
    // set up Pd audio session
    pdAudioController_ = [[PdAudioController alloc] init];
    [pdAudioController_ configurePlaybackWithSampleRate:44100
                                       numberChannels:2
                                         inputEnabled:YES
                                        mixingEnabled:YES];
    
    [pdAudioController_ configureTicksPerBuffer: 4];    // Audiobus wants your app to perform well at 256 frames
                                                        // Pd block size * ticks per buffer = buffer size (64 * 4 = 256)
    // open patch
    NSString *patchPath = [[NSBundle mainBundle] pathForResource: @"Main"
                                                          ofType: @"pd"];
    [PdBase openFile: [patchPath lastPathComponent]
                              path:[ patchPath stringByDeletingLastPathComponent]];

    
    // Set up Audiobus
    audiobusController = [[ABAudiobusController alloc]
                           initWithAppLaunchURL: [NSURL URLWithString :@"libpd+audiobus.audiobus://"]
                           apiKey:@"YOUR_API_KEY_HERE"];
    // Input Port
    inputPort_ = [audiobusController addInputPortNamed: @"MyApp Input"
                                                  title: NSLocalizedString(@"MyApp Main Input", @"")];
    inputPort_.attributes = ABInputPortAttributePlaysLiveAudio;
    
    // Output Port
    outputPort_ = [audiobusController addOutputPortNamed: @"MyApp Output"
                                                    title: NSLocalizedString(@"MyApp Main Output", @"")];
    
    // Init Audio Unit Wrapper
    audiobusAudioUnitWrapper = [[ABAudiobusAudioUnitWrapper alloc]
                                     initWithAudiobusController: audiobusController
                                     audioUnit: pdAudioController_.audioUnit.audioUnit
                                     output: outputPort_
                                     input: inputPort_];
    audiobusAudioUnitWrapper.useLowLatencyInputStream = YES;
    
    // Turn DSP on
    [self setActive: YES];
}

- (BOOL)isActive
{
    return pdAudioController_.isActive;
}

- (void)setActive:(BOOL)active {
    
    [pdAudioController_ setActive: active];
}

- (void)stop
{
    // stop everything
}

- (BOOL)audiobusConnected
{
    return [audiobusController connected];
}

#pragma mark - Notifications

// ABConnectionsChangedNotification
- (void)connectionsChanged:(NSNotification*)notification
{
    // Cancel any scheduled shutdown
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stop) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setActive:) object:nil];
    
    if ( audiobusController.connected ) {
        
        if (![self isActive]) [self setActive: YES];
        
        NSLog(@"AUDIOBUS CONNECTED");
        
    } else if ( !audiobusController.connected
               && [self isActive]
               && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground ) {
        
        // Shut down if we disconnect from AB while app is in the background
        
        // allow 10 seconds to return to app to without disturbing audio session
        
        [self performSelector:@selector(setActive:) withObject:NO afterDelay: 10.0];
    }
    
    // Check input port and notify Pd
    BOOL inputPortConneted = ABInputPortIsConnected( inputPort_ );
    
    [PdBase sendFloat:@(inputPortConneted).floatValue
           toReceiver:@"Input-Connected"];
}

-(void)applicationDidEnterBackground:(NSNotification *)notification
{
    if ( !audiobusController.connected ) {
        
        // Stop audio after 10 seconds when closing app which
        // should allow enough time to set up a connection in Audiobus
        
        [self performSelector:@selector(setActive:) withObject:NO afterDelay: 10.0];
    }
}

-(void)applicationWillEnterForeground:(UIApplication *)application
{
    // Cancel sheduled shutdown if we return to app from Audiobus
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setActive:) object:nil];
    
    if ( ![self isActive]) {    // Start the audio system if it's not already running
        
        [self setActive: YES];
    }
}

#pragma mark - PdBase delegate

- (void)receivePrint:(NSString *)message {
    NSLog(@"PD PRINT: %@", message);
}

@end
