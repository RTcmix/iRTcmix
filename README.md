# iRTcmix
RTcmix enables iOS developers to easily incorporate interactive sound into their iPhone, iPad and iPod Touch apps. The library includes the compiled RTcmix object and Objective-C classes for communicating with the RTcmix audio engine and for interacting with Minc scores.

The libiRTCMIX.a file is the library containing the compiled programs necessary to use iRTcmix on iOS simulators and devices.

The RTcmixPlayer.m and RTcmixPlayer.h files contain the code and object definitions for using iRTcmix in an iOS application.


Here is how to create an iRTcmix Xcode project:

1.  Start up Xcode, and under File->New select "Project..."

2.  Select a "Single-View Application" (unless you are planning something
	different and you know what you're doing) and hit "Next".

3.  Enter your project name and any other relevant information.  You don't
	need to have "Use Core Data" or the "Tests" selected.  Hit "Next".

4.  Create the project (hit "Create" on the next screen) where you want it
	in your filesystem.

5.  Copy the three files (libIRTCMIX.a, RTcmixPlayer.m, RTcmixPlayer.h)
	somewhere in your new project (I like to put mine in an RTcmix folder at
	the same level as the "AppDelegate" and "ViewController" files).

6.  Add the three files (or the “RTcmix" folder if you created one) to your project
	by dragging them from the Finder to your Xcode project file-listing on the
	left in the XCcode project (I like to put mine under the "Supporting Files" 
	entry).

7.  Copy items if needed, add to groups, etc. and hit "OK".

8.  Select the project in the top left, and click on the "Build Settings"
	tab so you can see all the things Xcode is set to do.  Scroll down
	to the "Linking" section, and find the "Other Linker Flags" entry.

9.  In the second column (under your project name), double-click the
	intersection of that column with the "Other Linker Flags" row and
	add "-lstdc++".

10.  In the "ViewController.h" file, change this:

			#import <UIKit/UIKit.h>

			@interface ViewController : UIViewController

	to this:

			#import <UIKit/UIKit.h>
			#import "RTcmixPlayer.h"

			@interface ViewController : UIViewController <RTcmixPlayerDelegate>

11.  In the "ViewController.m" file, change this:

			@interface ViewController ()

			@end

	to this:

			@interface ViewController ()
			@property (nonatomic, strong)       RTcmixPlayer		*rtcmixManager;
			@end

	and this:

			- (void)viewDidLoad {
			    [super viewDidLoad];
			    // Do any additional setup after loading the view, typically from a nib.
			}
			
	to this:

			- (void)viewDidLoad {
			    [super viewDidLoad];
			    
			    self.rtcmixManager = [RTcmixPlayer sharedManager];
			    self.rtcmixManager.delegate = self;
			    [self.rtcmixManager startAudio];
			}


Now you should be all set to add interface elements and RTcmix stuff!
Do good things!


