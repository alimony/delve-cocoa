//
// Delve
//
// © 2011 Markus Amalthea Magnuson <markus.magnuson@gmail.com>
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

@interface DelveAppDelegate : NSObject
{
    NSTask *task;
    NSString *publicAddress;
    BOOL scanInProgress;
    
    IBOutlet NSWindow *mainWindow;
    IBOutlet NSWindow *openingWindow;
    IBOutlet NSProgressIndicator *openingIndicator;
    IBOutlet NSArrayController *arrayController;
    IBOutlet NSTableView *tableView;
    IBOutlet NSButton *scanButton;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *scanText;
}

- (IBAction)startScan:(id)sender;
- (IBAction)stopScan:(id)sender;
- (NSArray *)addressRangeForPart:(NSNumber *)number;
- (void)scanAddresses;

@end
