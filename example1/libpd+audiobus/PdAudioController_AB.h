//
//  PdAudioController_AB.h
//  libpd+audiobus
//
//  Created by Ragnar Hrafnkelsson on 19/11/2013.
//  Copyright (c) 2013 Reactify. All rights reserved.
//

#import "PdAudioController.h"
#import "PdAudioUnit.h"

@interface PdAudioController ()

@property (nonatomic, readonly) PdAudioUnit *audioUnit; // Here we make the audioUnit available

@end
