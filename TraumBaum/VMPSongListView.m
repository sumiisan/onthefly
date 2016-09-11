//
//  VMPSongListView.m
//  OnTheFly
//
//  Created by sumiisan on 2014/02/16.
//
//

#import "VMPSongListView.h"
#import "VMAppDelegate.h"
#import "VMVmsarcManager.h"
#import "VMViewController.h"
#import "VMPMultiLanguage.h"

@interface VMPSongListView()
	@property (nonatomic,retain) NSMutableDictionary *vmsCacheTable;
	@property (nonatomic,retain) NSMutableArray *cacheIdList;
	@property (nonatomic,retain) NSString *detailViewingCacheId;
@end

@implementation VMPSongListView

- (void)resetMetricsToSize:(CGSize)size {
	UITableView *tb = (UITableView*)[self viewWithTag:888];
	self.frame = CGRectMake(0, 0, size.width, size.height);
	tb.frame = CGRectMake(0, 55, size.width, size.height-55);	//	minus navitation bar
	UINavigationBar *nb = (UINavigationBar*)[self viewWithTag:889];
	nb.frame = CGRectMake(0, 0, size.width, 55);
	
	if( [self popDetailViewAnimated:NO] )
		[self showDetailForCache:self.detailViewingCacheId size:size animated:NO];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		self.vmsCacheTable = [[[VMVmsarcManager defaultManager].vmsCacheTable mutableCopy] autorelease];
		self.cacheIdList = [[[[self.vmsCacheTable allKeys] sortedArrayUsingSelector:@selector(compare:)] mutableCopy] autorelease];
		
		UITableView *tv = [[UITableView alloc] init];
		tv.dataSource = self;
		tv.delegate = self;
		tv.tag = 888;
		[self addSubview:tv];
		
		UINavigationBar *nb = [[UINavigationBar alloc] init];
		UINavigationItem *ti = [[[UINavigationItem alloc] initWithTitle:[VMPMultiLanguage songlistTitle]] autorelease];
		ti.rightBarButtonItem = [VMAppDelegate defaultAppDelegate].viewController.editButtonItem;
		[nb pushNavigationItem:ti animated:NO];
		nb.tag = 889;
		[self addSubview:nb];
		[tv release];
		[nb release];
		
		[self resetMetricsToSize:self.frame.size];
		self.backgroundColor = [UIColor colorWithWhite:0.7 alpha:1.0];
	
	}
    return self;
}


- (void)dealloc {
	self.vmsCacheTable = nil;
	self.cacheIdList = nil;
	self.detailViewingCacheId = nil;
	[super dealloc];
}
	
#pragma mark - detail
- (void)showDetailForCache:(NSString*)cacheId size:(CGSize)size animated:(BOOL)animated {
	self.detailViewingCacheId = cacheId;
	NSDictionary *data = self.vmsCacheTable[cacheId];
	BOOL builtIn = [data[VMSCacheKey_BuiltIn] boolValue];
	
	CGFloat narrowerSide = MIN(size.width, size.height);
	CGFloat screenWidth = size.width;
	CGFloat imageHeight = narrowerSide * 0.625;

	UIView *detailView = [[[UIView alloc] initWithFrame:CGRectMake(animated ? screenWidth : 0, 55,
																  screenWidth, size.height - 55)] autorelease];
	
	UITextView *textv = [[[UITextView alloc] initWithFrame:CGRectMake(10, imageHeight + 3,
																	  screenWidth - 20,
																	  detailView.frame.size.height - imageHeight - 10 - 55 )] autorelease];
	
	textv.editable = NO;
	textv.dataDetectorTypes = UIDataDetectorTypeLink;
	textv.userInteractionEnabled = YES;
	textv.tag = 881;
	
	textv.backgroundColor = [UIColor clearColor];
	detailView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.];
	

	if( !builtIn ) {
		UIButton *bt = [UIButton buttonWithType:UIButtonTypeRoundedRect];
		[bt setTitle:@"Check for Update" forState:UIControlStateNormal];
		[bt addTarget:self action:@selector(checkUpdateButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
		bt.frame = CGRectMake(0, imageHeight +1, screenWidth, 50);
		bt.backgroundColor = [UIColor colorWithWhite:0. alpha:.1];
		bt.tag = 880;
		bt.titleLabel.textColor = [UIColor lightGrayColor];
		[detailView addSubview:bt];
		[VMVmsarcManager defaultManager].updateDelegate = self;
		[[VMVmsarcManager defaultManager] checkUpdatesForCacheId:self.detailViewingCacheId];
		bt.hidden = YES;
	}
	
	
	textv.text = [NSString stringWithFormat:@"Title:%@\nArtist: %@\n%@%@",
				  data[VMSCacheKey_SongName],
//				  data[VMSCacheKey_ArchiveId],
//				  data[VMSCacheKey_VmsId],
				  data[VMSCacheKey_Artist],
//				  builtIn ? @"Built in" : data[VMSCacheKey_DataUrl],
				  builtIn ? @"" : [NSString stringWithFormat:@"Downloaded at: %@\n", data[VMSCacheKey_Downloaded]],
				  data[VMSCacheKey_Website] ? [NSString stringWithFormat:@"Website: %@", data[VMSCacheKey_Website]] : @""
				  ];
	
	[detailView addSubview:textv];
	
	UIView *ib = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, imageHeight)] autorelease];
	ib.backgroundColor = [UIColor colorWithWhite:.8 alpha:1.];
	[detailView addSubview:ib];
	
	UIImageView *iv = [[[UIImageView alloc] initWithFrame:CGRectMake((screenWidth - imageHeight)*0.5 +1 , 1, imageHeight-2, imageHeight-2 )] autorelease];
	iv.image = [UIImage imageWithContentsOfFile:[[VMVmsarcManager defaultManager] artworkPathForCacheId:cacheId]];
	[detailView addSubview:iv];
	detailView.tag = 887;
	
	[self addSubview:detailView];
	
	UINavigationBar *nb = (UINavigationBar*)[self viewWithTag:889];
	UINavigationItem *ni = [[[UINavigationItem alloc] initWithTitle:data[VMSCacheKey_SongName]] autorelease];
	UITableView *tv = (UITableView*)[self viewWithTag:888];
	
	UIBarButtonItem *bbi = [[[UIBarButtonItem alloc] initWithTitle:@" < " style:UIBarButtonItemStylePlain target:self action:@selector(backButtonTouched:)] autorelease];
	ni.leftBarButtonItem = bbi;
	
	[nb pushNavigationItem:ni animated:YES];
	
	if( animated ) {
		[UIView animateWithDuration:0.5f
						 animations:^(){
							 tv.center = CGPointMake( tv.center.x - screenWidth, tv.center.y );
							 detailView.center = CGPointMake( detailView.center.x - screenWidth, detailView.center.y);
						 }
						 completion:^(BOOL finished){
							if( finished ) {
							}
						 }];
	}
}

- (BOOL)popDetailViewAnimated:(BOOL)animated {
	UIView *detailView = [self viewWithTag:887];
	if( !detailView ) return NO;
	
	UINavigationBar *nb = (UINavigationBar*)[self viewWithTag:889];
	[nb popNavigationItemAnimated:animated];
	UITableView *tv = (UITableView*)[self viewWithTag:888];

	if( animated ) {
		[UIView animateWithDuration:0.5f
						 animations:^(){
							 tv.center = CGPointMake( self.frame.size.width * 0.5, tv.center.y );
							 detailView.center = CGPointMake( detailView.center.x + self.frame.size.width, detailView.center.y);
						 }
						 completion:^(BOOL finished){
							 if( finished ) {
								 [detailView removeFromSuperview];
								 [tv reloadData];

							 }
						 }];
	} else {
		tv.center = CGPointMake( self.frame.size.width * 0.5, tv.center.y );
		[detailView removeFromSuperview];
	}

	return YES;
}


- (void)backButtonTouched:(id)sender {
	[self popDetailViewAnimated:YES];
}
	
	
- (void)checkUpdateButtonTapped:(id)sender {
	VMAppDelegate *app = [VMAppDelegate defaultAppDelegate];
	[app stop];
	[app saveSong:YES];
	[app savePlayerState];
	[app disposeQueue];
	[[VMVmsarcManager defaultManager] makeCurrent:self.detailViewingCacheId];
	
	[[VMAppDelegate defaultAppDelegate].viewController.infoViewController closeView];
	[[VMVmsarcManager defaultManager] reloadCacheId:self.detailViewingCacheId];
}
	
//	delegate
- (void)archiveUpdateAvailable:(NSString *)archiveId {
	if( [archiveId isEqualToString: self.vmsCacheTable[self.detailViewingCacheId][VMSCacheKey_ArchiveId]] ) {
		UIButton *bt = (UIButton *)[self viewWithTag:880];
		[bt setTitle:[VMPMultiLanguage updateArchiveMessage] forState:UIControlStateNormal];
		bt.alpha = 0.;
		bt.hidden = NO;
		UIView *tv = [self viewWithTag:881];
		
		[UIView animateWithDuration:0.5f animations:^(){
			tv.center = CGPointMake(tv.center.x, tv.center.y+52);
			bt.alpha = 1.;
		}];
		
	}
}
	
	
#pragma mark - Table view delegate
	
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *lastCacheId = [[VMVmsarcManager defaultManager] currentCacheId];
	VMAppDelegate *app = [VMAppDelegate defaultAppDelegate];
	if( [self switchToCacheId: self.cacheIdList[indexPath.row]] ) {
		[app resume];
		[app.viewController.infoViewController closeView];
	} else {
		[self switchToCacheId:lastCacheId];
		[app stop];
	}
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	[self showDetailForCache:self.cacheIdList[indexPath.row] size:self.frame.size animated:YES];
}

- (BOOL)switchToCacheId:(NSString*)cacheId {
	VMAppDelegate *app = [VMAppDelegate defaultAppDelegate];
	[app stop];
	[app saveSong:YES];
	[app savePlayerState];
	[app disposeQueue];
	[[VMVmsarcManager defaultManager] makeCurrent:cacheId];
	return [app loadSong];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return self.cacheIdList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if( ! cell ) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
		cell.textLabel.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];
		cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	}

	NSInteger row = indexPath.row;
	NSDictionary *d = self.vmsCacheTable[self.cacheIdList[row]];

    cell.textLabel.text = d[VMSCacheKey_SongName];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", d[VMSCacheKey_Artist]];
	
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *d = self.vmsCacheTable[self.cacheIdList[indexPath.row]];
    return ( ![d[VMSCacheKey_BuiltIn] boolValue] && [d[VMSCacheKey_VmsId] isEqualToString:@"default"] );
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *cacheId	= self.cacheIdList[indexPath.row];
		NSString *archiveId = self.vmsCacheTable[cacheId][VMSCacheKey_ArchiveId];
		
		if ( [VMVmsarcManager defaultManager].currentArchiveId == archiveId ) {
			//
			//	attempting delete current vms
			//
			[self switchToCacheId:[[VMVmsarcManager defaultManager] builtInCacheId]];		//	swtich to built-in vms
		}
		
		[[VMVmsarcManager defaultManager] deleteArchive:archiveId];
		[self.cacheIdList removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
	/*
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   */
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

@end
