//
//  MainViewController.m
//  99reddits
//
//  Created by Frank Jacob on 10/12/11.
//  Copyright 2011 99 reddits. All rights reserved.
//

#import "MainViewController.h"
#import "MainViewCell.h"
#import "NIHTTPRequest.h"
#import "AlbumViewController.h"
#import "RedditsViewController.h"
#import "UserDef.h"
#import "FeedbackController.h"
#import "_9reddits-Swift.h"

@interface MainViewController ()

@property (strong, nonatomic) UIBarButtonItem *helpBarButtonItem;
@property (strong, nonatomic) FeedbackController *feedbackController;
@property (strong, nonatomic) AlbumViewController *lastUsedAlbumViewController;
@property (strong, nonatomic) NSOperationQueue *refreshQueue;

@property (strong, nonatomic) IBOutlet UIView *mainTableViewFooter;
@property (weak, nonatomic) IBOutlet UIButton *addButton;

@end

@implementation MainViewController

@synthesize lastAddedIndex;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.feedbackController = [[FeedbackController alloc] init];

    appDelegate = (RedditsAppDelegate *)[[UIApplication sharedApplication] delegate];
    subRedditsArray = appDelegate.subRedditsArray;

    refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Pull to Refresh"];
    [refreshControl addTarget:self action:@selector(pullToRefresh:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.refreshControl beginRefreshing];
        [self.refreshControl endRefreshing];
    });

    self.title = @"99 edits";
    self.helpBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Help" style:UIBarButtonItemStylePlain target:self action:@selector(helpBarButtonItem:)];

    self.navigationItem.leftBarButtonItem = self.helpBarButtonItem;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;

    self.refreshQueue = [[NSOperationQueue alloc] init];
    [self.refreshQueue setMaxConcurrentOperationCount:5];

    refreshCount = 0;

    if (appDelegate.firstRun) {
        [self reloadData];
    }

    self.view.backgroundColor = [UIColor whiteColor];
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.tableView.separatorInset = UIEdgeInsetsZero;

    [self.addButton setBackgroundImage:[[UIImage imageNamed:@"ButtonNormal.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10, 0, 10)] forState:UIControlStateNormal];
    [self.addButton setBackgroundImage:[[UIImage imageNamed:@"ButtonHighlighted.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10, 0, 10)] forState:UIControlStateHighlighted];
    [self.addButton setBackgroundImage:[[UIImage imageNamed:@"ButtonNormal.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10, 0, 10)] forState:UIControlStateDisabled];

    lastAddedIndex = -1;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    CGRect frame = self.mainTableViewFooter.frame;
    frame.size.width = self.view.frame.size.width;
    self.mainTableViewFooter.frame = frame;
    self.tableView.tableFooterView = self.mainTableViewFooter;

    for (SubRedditItem *subReddit in subRedditsArray) {
        [subReddit calUnshowedCount];
    }
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (lastAddedIndex >= 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:lastAddedIndex + 1 inSection:0] atScrollPosition:UITableViewScrollPositionNone animated:YES];
        lastAddedIndex = -1;
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];

    if (self.editing) {
        self.refreshControl = nil;

        self.navigationItem.leftBarButtonItem.enabled = NO;
    }
    else {
        self.refreshControl = refreshControl;
        self.navigationItem.leftBarButtonItem.enabled = YES;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    [super prepareForSegue:segue sender:sender];

    if (self.editing) {
        return;
    }

    if (![segue.identifier isEqualToString:@"showDetail"]) {
        return;
    }

    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];

    AlbumViewController *albumViewController;

    if (indexPath.row == 0) {
        if (appDelegate.favoritesItem.photosArray.count > 0) {
            albumViewController = (AlbumViewController *)[[segue destinationViewController] topViewController];
            albumViewController.subReddit = appDelegate.favoritesItem;
            albumViewController.bFavorites = YES;
        }
    }
    else {
        SubRedditItem *subReddit = [subRedditsArray objectAtIndex:indexPath.row - 1];
        if (subReddit.photosArray.count > 0 && !subReddit.loading) {
            albumViewController = (AlbumViewController *)[[segue destinationViewController] topViewController];
            albumViewController.subReddit = subReddit;
            albumViewController.bFavorites = NO;
        }
    }

    self.lastUsedAlbumViewController = albumViewController;
    
}

- (void)helpBarButtonItem:(UIBarButtonItem *)sender {
    [self.feedbackController presentFeedbackViewController:self];
}

- (IBAction)onAddButton:(id)sender {
    RedditsViewController *redditsViewController = [[RedditsViewController alloc] initWithNibName:@"RedditsViewController" bundle:nil];
    redditsViewController.mainViewController = self;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:redditsViewController];
    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navigationController animated:YES completion:nil];
}

// UITableViewDatasource, UITableViewDelegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return subRedditsArray.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifer = @"MAINVIEWCELL";
    MainViewCell *cell = (MainViewCell *)[tableView dequeueReusableCellWithIdentifier:identifer];
    if (cell == nil) {
        cell = [[MainViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifer];
    }

    if (indexPath.row == 0) {
        cell.contentTextLabel.text = appDelegate.favoritesItem.nameString;

        if (appDelegate.favoritesItem.photosArray.count == 0) {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.contentImageView.image = [UIImage imageNamed:@"FavoritesIcon.png"];
        }
        else {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;

            NSString *urlString = [self cacheKeyForPhotoIndex:indexPath.row - 1];

            if (urlString) {
                [ImageLoader loadWithUrlString:urlString into:cell.contentImageView];
            } else {
                cell.contentImageView.image = [UIImage imageNamed:@"FavoritesIcon.png"];
            }
        }
    }
    else {
        SubRedditItem *subReddit = [subRedditsArray objectAtIndex:indexPath.row - 1];
        cell.contentTextLabel.text = subReddit.nameString;

        if (subReddit.photosArray.count == 0 || subReddit.loading) {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.contentImageView.image = nil;
        }
        else {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;

            NSString *urlString = [self cacheKeyForPhotoIndex:indexPath.row - 1];
            [ImageLoader loadWithUrlString:urlString into:cell.contentImageView];
        }

        [cell setUnseenCount:subReddit.unshowedCount isLoading:subReddit.loading];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self performSegueWithIdentifier:@"showDetail" sender:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.row == 0)
        return NO;

    if (refreshCount != 0)
        return NO;

    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        SubRedditItem *subReddit = [subRedditsArray objectAtIndex:indexPath.row - 1];
        subReddit.subscribe = NO;
        [appDelegate.nameStringsSet removeObject:[subReddit.nameString lowercaseString]];
        [subRedditsArray removeObject:subReddit];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];

        [appDelegate saveToDefaults];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.editing)
        return NO;

    if (indexPath.row == 0)
        return NO;

    if (refreshCount != 0)
        return NO;

    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    SubRedditItem *subReddit = [subRedditsArray objectAtIndex:fromIndexPath.row - 1];
    [subRedditsArray removeObjectAtIndex:fromIndexPath.row - 1];
    [subRedditsArray insertObject:subReddit atIndex:toIndexPath.row - 1];

    [appDelegate saveToDefaults];
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if (proposedDestinationIndexPath.row == 0)
        return sourceIndexPath;

    return proposedDestinationIndexPath;
}

- (void)pullToRefresh:(UIControl *)sender {

    if (self.splitViewController.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
        //If the gallery is shown on the right pane (e.g. iPad, iPhone 8+, clear out before refreshing.
        [self.lastUsedAlbumViewController clear];
    }

    [self reloadData];
}

- (void)reloadData {
    if (subRedditsArray.count == 0)
        return;

    if (![appDelegate checkNetworkReachable:YES])
        return;

    if (refreshCount != 0)
        return;

    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Refreshing..."];
    [self.refreshControl beginRefreshing];

    self.navigationItem.rightBarButtonItem.enabled = NO;

    refreshCount = 0;

    for (NSInteger i = 0; i < subRedditsArray.count; i ++) {
        SubRedditItem *subReddit = [subRedditsArray objectAtIndex:i];
        subReddit.loading = YES;

        refreshCount ++;

        NSURL *url = [NSURL URLWithString:subReddit.urlString];
        NIProcessorHTTPRequest* albumRequest = [NIJSONKitProcessorHTTPRequest requestWithURL:url usingCache:nil];
        albumRequest.shouldAttemptPersistentConnection = NO;
        albumRequest.timeOutSeconds = 30;
        albumRequest.delegate = self;
        albumRequest.userAgentString = @"Mozilla/5.0 (iPhone; CPU iPhone OS 10_1 like Mac OS X) AppleWebKit/602.2.14 (KHTML, like Gecko) Mobile/14B72";
        albumRequest.processorDelegate = (id)[self class];
        [self.refreshQueue addOperation:albumRequest];
    }

    [self.tableView reloadData];
}

// ASIHTTPRequestDelegate
- (void)requestFinished:(NIProcessorHTTPRequest *)request {
    NSString *urlString = [[request originalURL] absoluteString];

    SubRedditItem *subReddit = nil;
    NSInteger index = 0;
    for (NSInteger i = 0; i < subRedditsArray.count; i ++) {
        SubRedditItem *tempSubReddit = [subRedditsArray objectAtIndex:i];
        if ([tempSubReddit.urlString isEqualToString:urlString]) {
            subReddit = tempSubReddit;
            index = i;
            break;
        }
    }

    if (subReddit == nil) {
        refreshCount --;
        if (refreshCount == 0) {
            self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Pull to Refresh"];
            [self.refreshControl endRefreshing];

            self.navigationItem.rightBarButtonItem.enabled = YES;
        }
        return;
    }

    subReddit.loading = NO;
    subReddit.unshowedCount = 0;

    NSMutableArray *tempPhotosArray = [[NSMutableArray alloc] init];
    [tempPhotosArray addObjectsFromArray:subReddit.photosArray];

    NSDictionary *dictionary = (NSDictionary *)request.processedObject;
    [subReddit.photosArray removeAllObjects];
    [subReddit.photosArray addObjectsFromArray:[dictionary objectForKey:@"photos"]];

    subReddit.afterString = [dictionary objectForKey:@"after"];

    [subReddit calUnshowedCount];

    [self.tableView reloadData];

    [tempPhotosArray removeAllObjects];

    refreshCount --;
    if (refreshCount == 0) {
        self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Pull to Refresh"];
        [self.refreshControl endRefreshing];

        self.navigationItem.rightBarButtonItem.enabled = YES;
        [appDelegate saveToDefaults];
    }
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSString *urlString = [[request originalURL] absoluteString];

    SubRedditItem *subReddit = nil;
    NSInteger index = 0;
    for (NSInteger i = 0; i < subRedditsArray.count; i ++) {
        SubRedditItem *tempSubReddit = [subRedditsArray objectAtIndex:i];
        if ([tempSubReddit.urlString isEqualToString:urlString]) {
            subReddit = tempSubReddit;
            index = i;
            break;
        }
    }

    if (subReddit == nil) {
        refreshCount --;
        if (refreshCount == 0) {
            self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Pull to Refresh"];
            [self.refreshControl endRefreshing];

            self.navigationItem.rightBarButtonItem.enabled = YES;
        }
        return;
    }

    subReddit.loading = NO;
    subReddit.unshowedCount = 0;
    [subReddit.photosArray removeAllObjects];

    [self.tableView reloadData];

    refreshCount --;
    if (refreshCount == 0) {
        self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Pull to Refresh"];
        [self.refreshControl endRefreshing];

        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

// NIProcessorDelegate
+ (id)processor:(id)processor processObject:(id)object error:(NSError **)processingError {
    if (![object isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *data = [object objectForKey:@"data"];
    if (data == nil)
        return nil;

    NSDictionary *array = [data objectForKey:@"children"];
    if (array == nil)
        return nil;

    NSMutableArray *photosArray = [NSMutableArray arrayWithCapacity:array.count];
    for (NSDictionary *item in array) {
        NSDictionary *itemData = [item objectForKey:@"data"];

        PhotoItem *photo = [[PhotoItem alloc] init];
        photo.idString = [itemData objectForKey:@"id"];
        photo.nameString = [itemData objectForKey:@"name"];

        NSString *permalinkString = [itemData objectForKey:@"permalink"];
        if (!permalinkString)
            photo.permalinkString = @"";
        else if ([permalinkString hasPrefix:@"http"])
            photo.permalinkString = permalinkString;
        else
            photo.permalinkString = [NSString stringWithFormat:@"https://www.reddit.com%@.compact", permalinkString];

        photo.titleString = [RedditsAppDelegate stringByRemoveHTML:[itemData objectForKey:@"title"]];
        photo.urlString = [RedditsAppDelegate getImageURL:[itemData objectForKey:@"url"]];

        NSString *thumbnailString = [itemData objectForKey:@"thumbnail"];

        // If the thumbnail string is empty or a default value, AND the URL is an imgur link,
        // then we go to imgur to get the thumbnail
        // Small square [90x90px]:    http://i.imgur.com/46dFas.jpg
        if ([photo.urlString hasPrefix:@"http://i.imgur.com/"] || [photo.urlString hasPrefix:@"http://imgur.com/"]) {
            NSString *lastComp = [photo.urlString lastPathComponent];
            photo.thumbnailString = [NSString stringWithFormat:@"http://i.imgur.com/%@s.png", [lastComp stringByDeletingPathExtension]];
        }
        else {
            photo.thumbnailString = [RedditsAppDelegate getImageURL:thumbnailString];
        }
        
        NSString *extension = [[photo.urlString pathExtension] lowercaseString];
        if (extension.length != 0 && ([extension isEqualToString:@"jpg"] ||
                                      [extension isEqualToString:@"jpeg"] ||
                                      [extension isEqualToString:@"gif"] ||
                                      [extension isEqualToString:@"png"] ||
                                      [extension isEqualToString:@"tiff"] ||
                                      [extension isEqualToString:@"tif"] ||
                                      [extension isEqualToString:@"bmp"]
                                      )) {
            
            // However if the thumbnail is empty or a default value and NOT an imgur link,
            // we instead use the FULL image URL as the thumbnail...
            // Do we need this?  Does this result in us downloading photos twice if we don't have
            // an otherwise usable thumbnail?  (Aman 20-Dec-2011)
            if ((photo.thumbnailString.length == 0) ||
                [photo.thumbnailString isEqualToString:@"nsfw"] ||
                [photo.thumbnailString isEqualToString:@"default"])
                photo.thumbnailString = photo.urlString;

            [photosArray addObject:photo];
        }

    }

    NSString *afterString = [data objectForKey:@"after"];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:photosArray, @"photos", afterString, @"after", nil];

    return dictionary;
}

- (void)addSubReddit:(SubRedditItem *)subReddit {
    if (![appDelegate checkNetworkReachable:YES])
        return;

    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Refreshing..."];
    [self.refreshControl beginRefreshing];

    self.navigationItem.rightBarButtonItem.enabled = NO;

    subReddit.loading = YES;

    refreshCount ++;

    NSURL *url = [NSURL URLWithString:subReddit.urlString];
    NIProcessorHTTPRequest* albumRequest = [NIJSONKitProcessorHTTPRequest requestWithURL:url usingCache:nil];
    albumRequest.shouldAttemptPersistentConnection = NO;
    albumRequest.timeOutSeconds = 30;
    albumRequest.userAgentString = @"Mozilla/5.0 (iPhone; CPU iPhone OS 10_1 like Mac OS X) AppleWebKit/602.2.14 (KHTML, like Gecko) Mobile/14B72";
    albumRequest.delegate = self;
    albumRequest.processorDelegate = (id)[self class];
    [self.refreshQueue addOperation:albumRequest];
}

- (NSString *)cacheKeyForPhotoIndex:(NSInteger)photoIndex {
    if (photoIndex == -1) {
        if (appDelegate.favoritesItem.photosArray.count == 0)
            return @"";

        return [[appDelegate.favoritesItem.photosArray objectAtIndex:0] thumbnailString];
    }
    else {
        SubRedditItem *subReddit = [subRedditsArray objectAtIndex:photoIndex];
        if (subReddit.photosArray.count == 0)
            return @"";

        return [[subReddit.photosArray objectAtIndex:0] thumbnailString];
    }
}

@end
