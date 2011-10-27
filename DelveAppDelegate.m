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

#import "DelveAppDelegate.h"

@implementation DelveAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Display a sheet dialog while getting our public address.
    [openingIndicator startAnimation:self];
    [NSApp beginSheet:openingWindow
       modalForWindow:mainWindow
        modalDelegate:self
       didEndSelector:nil
          contextInfo:nil];

    NSError *error = nil;
    NSString *result = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://api.externalip.net/ip/"]
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
    // TODO: Regex the result to see if we actually got an IP address.
    if (error) {
        NSLog(@"Couldn't get public address: %@", [error localizedDescription]);
        // We couldn't determine the public address, so quit.
        // TODO: Do something more graceful than quitting.
        NSRunCriticalAlertPanel(@"Couldn't get public address",
                                @"Your public address could not be determined.",
                                @"Quit",
                                nil,
                                nil);
        [NSApp endSheet:openingWindow];
        [openingWindow orderOut:self];
        [NSApp terminate:nil];
    }
    else {
        publicAddress = result;
        [publicAddress retain];
    }
    
    [scanText setStringValue:[NSString stringWithFormat:@"Scan will start at %@", publicAddress]];
    [openingIndicator stopAnimation:self];
    
    [NSApp endSheet:openingWindow];
    [openingWindow orderOut:self];

    [tableView setTarget:self];
    [tableView setDoubleAction:@selector(didDoubleClickRow:)];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    if (scanInProgress) {
        [self stopScan:self];
    }
}

- (IBAction)startScan:(id)sender
{
    scanInProgress = YES;

    // Always start from an empty array of found paths.
    [arrayController removeObjects:[arrayController arrangedObjects]];
    
    [progressIndicator startAnimation:self];
    [scanButton setTitle:@"Stop Scan"];
    [scanButton setAction:@selector(stopScan:)];
    
    [NSThread detachNewThreadSelector:@selector(scanAddresses) toTarget:self withObject:nil];
}

- (IBAction)stopScan:(id)sender
{
    if ([task isRunning]) {
        [task terminate];
    }

    scanInProgress = NO;
    
    [progressIndicator stopAnimation:self];
    [scanText setStringValue:@"Stopped scanning."];
    [scanButton setTitle:@"Start Scan"];
    [scanButton setAction:@selector(startScan:)];
}

- (void)didDoubleClickRow:(id)sender
{
    NSString *remoteURL = [[arrayController arrangedObjects] objectAtIndex:[sender clickedRow]];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:remoteURL]];
}

- (NSArray *)addressRangeForPart:(NSNumber *)number
{
    int part = [number intValue];
    
    NSMutableArray *upperNumbers = [NSMutableArray array];
    for (int i = part; i < 256; i++) {
        [upperNumbers addObject:[NSNumber numberWithInt:i]];
    }
    NSMutableArray *lowerNumbers = [NSMutableArray array];
    for (int i = part - 1; i >= 0; i--) {
        [lowerNumbers addObject:[NSNumber numberWithInt:i]];
    }
    
    NSMutableArray *numbers = [NSMutableArray array];
    while ([upperNumbers count] > 0 || [lowerNumbers count] > 0) {
        if ([upperNumbers count] > 0) {
            [numbers addObject:[upperNumbers objectAtIndex:0]];
            [upperNumbers removeObjectAtIndex:0];
        }
        if ([lowerNumbers count] > 0) {
            [numbers addObject:[lowerNumbers objectAtIndex:0]];
            [lowerNumbers removeObjectAtIndex:0];
        }
    }
    
    return [NSArray arrayWithArray:numbers];
}

- (void)scanAddresses
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSArray *publicAddressParts = [publicAddress componentsSeparatedByString:@"."];
    NSArray *partOne = [self addressRangeForPart:[publicAddressParts objectAtIndex:0]];
    NSArray *partTwo = [self addressRangeForPart:[publicAddressParts objectAtIndex:1]];
    NSArray *partThree = [self addressRangeForPart:[publicAddressParts objectAtIndex:2]];
    
    for (NSNumber *partOneNumber in partOne) {
        if (!scanInProgress) {
            break;
        }
        for (NSNumber *partTwoNumber in partTwo) {
            if (!scanInProgress) {
                break;
            }
            for (NSNumber *partThreeNumber in partThree) {
                if (!scanInProgress) {
                    break;
                }
                NSString *searchAddress = [NSString stringWithFormat:@"%@.%@.%@.0-255", partOneNumber, partTwoNumber, partThreeNumber];
                [scanText setStringValue:[NSString stringWithFormat:@"Scanning %@…", searchAddress]];
                
                // TODO: Look for SMB drives too (port 445) and add them as smb:// links.
                NSString *command = [NSString stringWithFormat:@"%@/nmap -vv -p548 %@ | grep \"Discovered open port\" | cut -d \" \" -f 6 | xargs -I {} echo \"afp://{}\"", [[NSBundle mainBundle] resourcePath], searchAddress];
                
                task = [[[NSTask alloc] init] autorelease];
                [task setLaunchPath:@"/bin/sh"];
                [task setArguments:[NSArray arrayWithObjects:@"-c", command, nil]];
                
                NSPipe *pipe  = [NSPipe pipe];
                [task setStandardOutput:pipe];
                NSFileHandle *file = [pipe fileHandleForReading];
                
                [task launch];
                
                NSData *data = [file readDataToEndOfFile];
                NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSMutableArray *foundPaths = [NSMutableArray arrayWithArray:[string componentsSeparatedByString:@"\n"]];
                [string release];
                
                [foundPaths removeObject:@""];
                [arrayController addObjects:foundPaths];
                
                [task waitUntilExit];
            }
        }
    }
    
    [self stopScan:self];
    
    [pool release];
}

@end
