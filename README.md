libpd-audiobus
==============

libpd and Audiobus example - Working with Audiobus v2.1.5

The Audiobus developer site has very good documentation on how to configure your app. You'll need to head there to obtain a copy of the SDK and an API key.  Go through the steps outlined by Audiobus to add the SDK to your project. If you have an existing libpd setup, it shouldn't need to change at all. We'll set this up without modifying libpd source code, so we can set our Pd session up just as we normally would.

The ABAudiobusController needs access to our app’s AudioUnit. In libpd, this resides inside the PdAudioUnit class. Because we're using the PdAudioController class to handle audio setup, we never directly access PdAudioUnit. In fact, it is protected inside the PdAudioController implementation file and that’s what we have to address. (You could write your own Pd AudioController, but it’s set up for us already so we’ll stick to using it). Leaving the libpd files untouched, let’s create a new class extension, New File.. -> Objective-C class extension, and name it ‘AB’ and have it extend PdAudioController class. This will create a new file called PdAudioController_AB.h. In there, add the following property:

@property (nonatomic, readwrite) PdAudioUnit *audioUnit;

This will allow us to access the (previously) protected PdAudioUnit property. In your audio session setup, make sure to change the #import “PdAudioController.h” line to our new “PdAudioController_AB.h”.

The AudioManager class handles changes to Aubiobus connections, enabling Pd mic input if our app is being used as a Filter or Receiver, and muting it when in Sender mode, instead playing a drum loop.
