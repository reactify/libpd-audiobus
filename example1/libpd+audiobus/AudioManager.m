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


@interface AudioManager () <PdReceiverDelegate>

@property (nonatomic) BOOL initialised;
@property (nonatomic, strong) PdAudioController *pdAudioController;
@property (nonatomic, strong) ABAudiobusController *audiobusController;

@end


@implementation AudioManager


+ (instancetype)sharedInstance
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self class] new];
    });
    return sharedInstance;
}

- (void)dealloc
{
	_pdAudioController = nil;
	_audiobusController = nil;
}

- (id)init
{
	self = [super init];
	if (!self) return nil;
	
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
	[self setup];
	
    return self;
}

- (void)setup
{
    if (_initialised) return;
    
    [PdBase setDelegate: self];     // register for Pd messages
    
    // set up Pd audio controller
    self.pdAudioController = [[PdAudioController alloc] init];
    [self.pdAudioController configurePlaybackWithSampleRate:44100
											 numberChannels:2
											   inputEnabled:YES
											  mixingEnabled:YES];
    [self.pdAudioController configureTicksPerBuffer: 4]; // Audiobus wants your app to perform well at 256 frames
														// Pd block size * ticks per buffer = buffer size (64 * 4 = 256)
    // open patch
    NSString *patchPath = [[NSBundle mainBundle] pathForResource:@"Main"
                                                          ofType:@"pd"];
    [PdBase openFile: [patchPath lastPathComponent]
                              path:[ patchPath stringByDeletingLastPathComponent]];

    
    // Set up Audiobus
	NSString *apiKey = @"YOUR_API_KEY_HERE";
	
	self.audiobusController = [[ABAudiobusController alloc] initWithApiKey:apiKey];
	self.audiobusController.connectionPanelPosition = ABConnectionPanelPositionRight;
	
	// The state delegate handles saving and recalling states from within Audiobus (Optional)
	// self.audiobusController.stateIODelegate = self;
	
	// Add receiver port
	ABReceiverPort *receiver = [[ABReceiverPort alloc] initWithName:@"My App Input" title:NSLocalizedString(@"MyApp Main Output", @"")];
	receiver.receiveMixedAudio = NO;
	[self.audiobusController addReceiverPort: receiver];
	
	AudioUnit audioUnit = self.pdAudioController.audioUnit.audioUnit;
	// Add sender port
	ABSenderPort *sender = [[ABSenderPort alloc] initWithName:@"My App Output"
														title:NSLocalizedString(@"MyApp Main Output", @"")
									audioComponentDescription:(AudioComponentDescription) {
										.componentType = kAudioUnitType_RemoteGenerator,
										.componentSubType = 'aout', // Note single quotes
										.componentManufacturer = 'mapp' }
													audioUnit:audioUnit];
	[self.audiobusController addSenderPort:sender];
	
	// Add filter port
	ABFilterPort *filter = [[ABFilterPort alloc] initWithName:@"My App Filter"
														title:NSLocalizedString(@"MyApp Main Filter Port", @"")
									audioComponentDescription:(AudioComponentDescription) {
										.componentType = kAudioUnitType_RemoteEffect,
										.componentSubType = 'filt',
										.componentManufacturer = 'mapp' }
													audioUnit:audioUnit];
	[self.audiobusController addFilterPort:filter];
	
	_initialised = YES;
}

- (BOOL)isActive
{
    return self.pdAudioController.isActive;
}

- (void)setActive:(BOOL)active
{
    self.pdAudioController.active = active;
}

- (BOOL)audiobusConnected
{
    return self.audiobusController.audiobusConnected;
}

#pragma mark - Notifications

// ABConnectionsChangedNotification
- (void)connectionsChanged:(NSNotification*)notification
{
    // Cancel any scheduled shutdown
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stop) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setActive:) object:nil];
    
    if ( self.audiobusController.connected )
	{
		if ( !self.isActive ) self.active = YES;
		
        NSLog(@"AUDIOBUS CONNECTED");
    }
	else if ( !self.audiobusController.connected
               && self.isActive
               && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground )
	{
        // Shut down if we disconnect from AB while app is in the background
        // allow 10 seconds to return to app to without disturbing audio session
        [self performSelector:@selector(setActive:) withObject:NO afterDelay: 10.0];
    }
    
    // Check input port and notify Pd
	BOOL inputConnected = ABReceiverPortIsConnected(self.audiobusController.receiverPorts[0]) || ABFilterPortIsConnected(self.audiobusController.filterPorts[0]);
	
    [PdBase sendFloat:@(inputConnected).floatValue
           toReceiver:@"Input-Connected"];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
	if ( !_audiobusController.connected && !_audiobusController.memberOfActiveAudiobusSession )
	{
		// Stop audio after 10 seconds when closing app which
		// should allow enough time to set up a connection in Audiobus
		
		[self performSelector:@selector(setActive:) withObject:NO afterDelay: 10.0];
	}
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Cancel sheduled background shutdown
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setActive:) object:nil];
    
	if ( !self.isActive ) self.active = YES; // Start the audio system if it's not already running
}

#pragma mark - PdBase delegate

- (void)receivePrint:(NSString *)message
{
    NSLog(@"PD PRINT: %@", message);
}

@end
