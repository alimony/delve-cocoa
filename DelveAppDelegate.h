//
// Delve
//
// © 2011–2012 Markus Amalthea Magnuson <markus@polyscopic.works>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import <Cocoa/Cocoa.h>

@class ASIHTTPRequest;

@interface DelveAppDelegate : NSObject
{
    NSTask *task;
    NSString *publicAddress;
    BOOL scanIsInProgress;
    NSString *pathBeingSent;
    NSWindow *connectionOriginatingWindow;

    IBOutlet NSArrayController *arrayController;

    // Main window.
    IBOutlet NSWindow *mainWindow;
    IBOutlet NSTableView *tableView;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *scanText;
    IBOutlet NSButton *scanButton;

    // Preferences window.
    IBOutlet NSWindow *preferencesWindow;
    IBOutlet NSTextField *serverField;
    IBOutlet NSProgressIndicator *serverTestingIndicator;
    IBOutlet NSImageView *serverStatusImage;
    IBOutlet NSTextField *serverStatusText;
    IBOutlet NSButton *serverTestButton;

    // Opening window.
    IBOutlet NSWindow *openingWindow;
    IBOutlet NSProgressIndicator *openingIndicator;

    // Login window.
    IBOutlet NSWindow *loginWindow;
    IBOutlet NSTextField *host;
	IBOutlet NSTextField *realm;
	IBOutlet NSTextField *username;
	IBOutlet NSTextField *password;
}

- (IBAction)startScan:(id)sender;
- (IBAction)stopScan:(id)sender;
- (NSArray *)addressRangeForPart:(NSNumber *)number;
- (void)scanAddresses;
- (void)sendPathToServer:(NSString *)path;
- (void)sendPathToServerDidFinish:(ASIHTTPRequest *)request;
- (void)sendPathToServerDidFail:(ASIHTTPRequest *)request;
- (IBAction)dismissAuthSheet:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)testServer:(id)sender;

@end
