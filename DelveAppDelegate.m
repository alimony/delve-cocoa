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

#import "DelveAppDelegate.h"
#import "ASIFormDataRequest.h"

@implementation DelveAppDelegate

+ (void)initialize
{
    NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"", DelvePreferencesKeyServer,
                              [NSNumber numberWithBool:NO], DelvePreferencesKeyShouldSendPathsToServer,
                              nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Display a sheet dialog while getting our public address.
    [openingIndicator startAnimation:self];
    [mainWindow beginSheet:openingWindow
         completionHandler:nil];

    NSError *error = nil;
    NSString *result = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"https://icanhazip.com/"]
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
        [mainWindow endSheet:openingWindow];
        [openingWindow orderOut:self];
        [NSApp terminate:nil];
    }
    else {
        publicAddress = result;
        [publicAddress retain];
    }

    [scanText setStringValue:[NSString stringWithFormat:@"Scan will start at %@", publicAddress]];
    [openingIndicator stopAnimation:self];

    [mainWindow endSheet:openingWindow];
    [openingWindow orderOut:self];

    [tableView setTarget:self];
    [tableView setDoubleAction:@selector(didDoubleClickRow:)];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:DelvePreferencesKeyShouldSendPathsToServer]) {
        [serverStatusImage setImage:[NSImage imageNamed:@"GreenDot"]];
        [serverStatusImage setHidden:NO];
        [serverStatusText setStringValue:@"Server OK"];
        [serverStatusText setHidden: NO];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    if (scanIsInProgress) {
        [self stopScan:self];
    }
}

- (IBAction)showPreferences:(id)sender
{
    [preferencesWindow makeKeyAndOrderFront:self];
}

- (IBAction)startScan:(id)sender
{
    scanIsInProgress = YES;

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

    scanIsInProgress = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [progressIndicator stopAnimation:self];
        [scanText setStringValue:@"Stopped scanning."];
        [scanButton setTitle:@"Start Scan"];
        [scanButton setAction:@selector(startScan:)];
    });
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
        if (!scanIsInProgress) {
            break;
        }
        for (NSNumber *partTwoNumber in partTwo) {
            if (!scanIsInProgress) {
                break;
            }
            for (NSNumber *partThreeNumber in partThree) {
                if (!scanIsInProgress) {
                    break;
                }
                NSString *searchAddress = [NSString stringWithFormat:@"%@.%@.%@.0-255", partOneNumber, partTwoNumber, partThreeNumber];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [scanText setStringValue:[NSString stringWithFormat:@"Scanning %@…", searchAddress]];
                });

                NSString *resourcePath = [[[NSBundle mainBundle] resourcePath] stringByReplacingOccurrencesOfString:@" "
                                                                                                         withString:@"\\ "];
                NSString *command = [NSString stringWithFormat:@"%@/nmap -vv -p548,139,445 %@ "
                                                                "| grep \"Discovered open port\" "
                                                                "| sed 's/\\/tcp//g' "
                                                                "| awk '{ "
                                                                    "if ($4 == 139 || $4 == 445) "
                                                                        "protocol = \"smb\"; "
                                                                    "else if ($4 == 548) "
                                                                        "protocol = \"afp\"; "
                                                                    "print protocol\"://\"$6 "
                                                                  "}'", resourcePath, searchAddress];
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

                // Remove empty and duplicate paths.
                [foundPaths removeObject:@""];
                NSArray *uniqueFoundPaths = [[NSSet setWithArray:foundPaths] allObjects];

                for (NSString *path in uniqueFoundPaths) {
                    if (![[arrayController arrangedObjects] containsObject:path]) {
                        // We found something new, display it and optionally notice server.
                        [arrayController addObject:path];
                        if ([[NSUserDefaults standardUserDefaults] boolForKey:DelvePreferencesKeyShouldSendPathsToServer]) {
                            [self sendPathToServer:path];
                        }
                    }
                }

                [task waitUntilExit];
            }
        }
    }

    [self stopScan:self];

    [pool release];
}

#pragma mark -
#pragma mark Sending found paths to server

- (void)sendPathToServer:(NSString *)path
{
    pathBeingSent = path;
    NSURL *url = [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:DelvePreferencesKeyServer]];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setUseKeychainPersistence:YES];

    // Add the POST data.
    [request addPostValue:path forKey:@"path"];

    // Handle responses.
    [request setDelegate:self];
	[request setDidFinishSelector:@selector(sendPathToServerDidFinish:)];
    [request setDidFailSelector:@selector(sendPathToServerDidFail:)];

    connectionOriginatingWindow = mainWindow;
	[request startAsynchronous];
}

- (void)sendPathToServerDidFinish:(ASIFormDataRequest *)request
{
    // TODO: We can probably do away with the pathsBeingSent variable by
    // getting the sent paths from the request's POST data instead.
    NSLog(@"Successfully sent %@ to server.", pathBeingSent);
    pathBeingSent = nil;
}

- (void)sendPathToServerDidFail:(ASIFormDataRequest *)request
{
	NSLog(@"%@", [request error]);
}

#pragma mark -
#pragma mark Testing the server connection

// Delegate method for listening to changes of the server address.
- (void)controlTextDidChange:(NSNotification *)aNotification
{
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:DelvePreferencesKeyShouldSendPathsToServer];
    BOOL serverFieldIsEmpty = [[serverField stringValue] isEqualToString:@""];
    [serverStatusImage setImage:[NSImage imageNamed:@"YellowDot"]];
    [serverStatusImage setHidden:serverFieldIsEmpty];
    [serverStatusText setStringValue:@"Server not tested"];
    [serverStatusText setHidden:serverFieldIsEmpty];
    [serverTestButton setEnabled:!serverFieldIsEmpty];
}

- (IBAction)testServer:(id)sender
{
    [serverStatusImage setHidden:YES];
    [serverStatusText setStringValue:@"Testing server…"];
    [serverStatusText setHidden:NO];
    [serverTestingIndicator startAnimation:self];

    NSURL *url = [NSURL URLWithString:[serverField stringValue]];
    ASIHTTPRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setUseKeychainPersistence:YES];

    [request setDelegate:self];
	[request setDidFinishSelector:@selector(serverTestDidFinish:)];
    [request setDidFailSelector:@selector(serverTestDidFail:)];

    connectionOriginatingWindow = preferencesWindow;
	[request startAsynchronous];
}

- (void)serverTestDidFinish:(ASIHTTPRequest *)request
{
    [serverStatusImage setImage:[NSImage imageNamed:@"GreenDot"]];
    [serverStatusImage setHidden:NO];
    [serverStatusText setStringValue:@"Server OK"];
    [serverTestingIndicator stopAnimation:self];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:DelvePreferencesKeyShouldSendPathsToServer];
}

- (void)serverTestDidFail:(ASIHTTPRequest *)request
{
	NSLog(@"%@", [request error]);
    [serverStatusImage setImage:[NSImage imageNamed:@"RedDot"]];
    [serverStatusImage setHidden:NO];
    [serverStatusText setStringValue:@"Couldn't connect to server"];
    [serverTestingIndicator stopAnimation:self];
}

#pragma mark -
#pragma mark Server authentication

// Delegate method to let the user authenticate. This is used both when sending
// paths and when testing the server connection.
- (void)authenticationNeededForRequest:(ASIHTTPRequest *)request
{
    [realm setStringValue:[request authenticationRealm]];
	[host setStringValue:[[request url] host]];

    [connectionOriginatingWindow makeKeyAndOrderFront:self];
	[NSApp beginSheet:loginWindow
       modalForWindow:connectionOriginatingWindow
		modalDelegate:self
       didEndSelector:@selector(authSheetDidEnd:returnCode:contextInfo:)
          contextInfo:request];
}

- (IBAction)dismissAuthSheet:(id)sender
{
    [NSApp endSheet:loginWindow returnCode:[(NSControl *)sender tag]];
}

- (void)authSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	ASIHTTPRequest *request = (ASIHTTPRequest *)contextInfo;

    if (returnCode == NSAlertFirstButtonReturn) {
        [request setUsername:[[[username stringValue] copy] autorelease]];
        [request setPassword:[[[password stringValue] copy] autorelease]];
		[request retryUsingSuppliedCredentials];
    }
    else {
		[request cancelAuthentication];
	}

    [loginWindow orderOut:self];
    connectionOriginatingWindow = nil;
}

@end
