//
//  ComposeMessageViewController.m
//  TextSecureiOS
//
//  Created by Frederic Jacobs on 10/30/13.
//  Copyright (c) 2013 Open Whisper Systems. All rights reserved.
//

#import "ComposeMessageViewController.h"
#import "TSMessagesManager.h"
#import "TSContactManager.h"
#import "TSContact.h"
#import "TSMessagesDatabase.h"
#import "TSMessage.h"
#import "TSThread.h"
#import "TSKeyManager.h"

@interface ComposeMessageViewController ()
@property (nonatomic, retain) NSArray *contacts;
@end

@implementation ComposeMessageViewController {
	TITokenFieldView * _tokenFieldView;
	
	CGFloat _keyboardHeight;
}

- (id) initWithConversationID:(TSContact*)contact {
#warning this isn't supporting group messaging yet, obviously
    self = [super initWithNibName:nil bundle:nil];

    if (!self) return nil;
    
    self.title = contact.name;
    self.contact = contact;
  
    [self setupThreadWithContact];
    return self;
}

-(void) setupThreadWithContact {
  TSContact *me = [[TSContact alloc] initWithRegisteredID:[TSKeyManager getUsernameToken]];
  self.thread = [TSThread threadWithParticipants:[[TSParticipants alloc] initWithTSContactsArray:@[me,self.contact]]];
}

- (id) initNewConversation {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.title = @"New Message";
    
    
	_tokenFieldView = [[TITokenFieldView alloc] initWithFrame:self.view.bounds];
    [_tokenFieldView setForcePickSearchResult:YES];
    
	[_tokenFieldView.tokenField setDelegate:self];
    _tokenFieldView.tokenField.delegate = self;
	[_tokenFieldView.tokenField addTarget:self action:@selector(tokenFieldFrameDidChange:) forControlEvents:(UIControlEvents) TITokenFieldControlEventFrameDidChange];
	[_tokenFieldView.tokenField setTokenizingCharacters:[NSCharacterSet characterSetWithCharactersInString:@",;."]]; // Default is a comma
    [_tokenFieldView.tokenField setPromptText:@"To:"];
	[_tokenFieldView.tokenField setPlaceholder:@"Type a name"];
	
    [_tokenFieldView.tokenField addTarget:self action:@selector(tokenFieldChangedEditing:) forControlEvents:UIControlEventEditingDidBegin];
	[_tokenFieldView.tokenField addTarget:self action:@selector(tokenFieldChangedEditing:) forControlEvents:UIControlEventEditingDidEnd];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[_tokenFieldView setHidden:TRUE];
    
    [self.view addSubview:_tokenFieldView];
    
	// You can call this on either the view on the field.
	// They both do the same thing.
	[_tokenFieldView becomeFirstResponder];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [TSContactManager getAllContactsIDs:^(NSArray *contacts) {
        _tokenFieldView.hidden = FALSE;
        
        [_tokenFieldView setSourceArray:contacts];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:FALSE];
        
        [_tokenFieldView becomeFirstResponder];
    }];
    
  
    UIBarButtonItem *dismissButton = [[UIBarButtonItem alloc] initWithTitle:@"Dismiss" style:UIBarButtonItemStylePlain target:self action:@selector(dismissVC)];
    
    self.navigationItem.leftBarButtonItem = dismissButton;
    
    return self;
}

- (void) dismissVC {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageRecieved) name:TSDatabaseDidUpdateNotification object:nil];
    self.delegate = self;
    self.dataSource = self;
    self.inputToolBarView.textView.delegate = self;
	[self.view setBackgroundColor:[UIColor whiteColor]];
    self.tableView.frame = CGRectMake(0, 0, self.tableView.frame.size.width, self.view.frame.size.height - 44);
}

- (void)keyboardWillShow:(NSNotification *)notification {
	
	CGRect keyboardRect = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	_keyboardHeight = keyboardRect.size.height > keyboardRect.size.width ? keyboardRect.size.width : keyboardRect.size.height;
	[self resizeViews];
}

- (void)keyboardWillHide:(NSNotification *)notification {
	_keyboardHeight = 0;
	[self resizeViews];
}

- (void)resizeViews {
	if (_tokenFieldView) {
        if (_keyboardHeight == 0) {
            [_tokenFieldView setFrame:((CGRect){_tokenFieldView.frame.origin, {self.view.bounds.size.width, 30.0f}})];
        } else{
            [_tokenFieldView setFrame:((CGRect){_tokenFieldView.frame.origin, {self.view.bounds.size.width, self.view.bounds.size.height - _keyboardHeight - 46.0f}})];
        }
    }
}

- (BOOL)tokenField:(TITokenField *)tokenField willRemoveToken:(TIToken *)token {
	return YES;
}

- (void)tokenFieldChangedEditing:(TITokenField *)tokenField {
	// There's some kind of annoying bug where UITextFieldViewModeWhile/UnlessEditing doesn't do anything.
	[tokenField setRightViewMode:(tokenField.editing ? UITextFieldViewModeAlways : UITextFieldViewModeNever)];
}

- (void)tokenFieldFrameDidChange:(TITokenField *)tokenField {
    
}

- (NSString *)tokenField:(TITokenField *)tokenField searchResultStringForRepresentedObject:(id)object {
    return [(TSContact*)object name];
}

- (NSString *)tokenField:(TITokenField *)tokenField displayStringForRepresentedObject:(id)object {
    return [(TSContact*)object name];
}

- (UIButton *)sendButton {
    // Override to use a custom send button
    // The button's frame is set automatically for you
    return [UIButton defaultSendButton];
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  NSLog(@"messages on thread: %d",[[TSMessagesDatabase getMessagesOnThread:self.thread] count]);
    return [[TSMessagesDatabase getMessagesOnThread:self.thread] count];
}

#pragma mark - Messages view delegate

- (void)sendPressed:(UIButton *)sender withText:(NSString *)text {
    // We remove the token field because we don't want the user to be able to edit the receipients list again
    
    if (_tokenFieldView) {
        [_tokenFieldView removeFromSuperview];
        self.title = [NSString stringWithFormat:@"%@", [_tokenFieldView.tokenField.tokenTitles objectAtIndex:0]];
        _tokenFieldView = nil;
    }
  
    TSMessage *message = [[TSMessage alloc] initWithMessage:text sender:[TSKeyManager getUsernameToken] recipients:[[NSArray alloc] initWithObjects:self.contact.registeredID, nil] sentOnDate:[NSDate date]];
    [self messageSent:message];
    [[TSMessagesManager sharedManager] sendMessage:message];

    [self finishSend];
}

-(void) messageSent:(TSMessage*) message {
  [JSMessageSoundEffect playMessageSentSound];
  [self addMessage:message];
}

-(void) messageRecieved {
  [JSMessageSoundEffect playMessageReceivedSound];
  [self.tableView reloadData];

}

-(void)addMessage:(TSMessage*)message {
    // TODO: error handling
  [TSMessagesDatabase storeMessage:message];
  [self.tableView reloadData];
}

- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath {

    //TODO: error handling
  NSArray *dbMessages = [TSMessagesDatabase getMessagesOnThread:self.thread];
  
  if([[[dbMessages objectAtIndex:indexPath.row] senderId] isEqualToString:[TSKeyManager getUsernameToken]]) {
    return JSBubbleMessageTypeOutgoing;
  }
   else {
     return  JSBubbleMessageTypeIncoming;
   }
}

- (JSBubbleMessageStyle)messageStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return JSBubbleMessageStyleFlat;
}

- (JSMessagesViewTimestampPolicy)timestampPolicy {
    return JSMessagesViewTimestampPolicyEveryThree;
}

- (JSMessagesViewAvatarPolicy)avatarPolicy {
    return JSMessagesViewAvatarPolicyNone;
}

- (JSAvatarStyle)avatarStyle {
    return JSAvatarStyleSquare;
}

- (JSInputBarStyle)inputBarStyle {
    return JSInputBarStyleFlat;
}

#pragma mark - Messages view data source

- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath {
    //TODO: error handling
    NSArray *dbMessages = [TSMessagesDatabase getMessagesOnThread:self.thread];
    return [[dbMessages objectAtIndex:indexPath.row] message];
}

- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    //TODO: error handling
    NSArray *dbMessages = [TSMessagesDatabase getMessagesOnThread:self.thread];
    return [[dbMessages objectAtIndex:indexPath.row]  messageTimestamp];
}

- (UIImage *)avatarImageForIncomingMessage {
    return nil;
}

- (UIImage *)avatarImageForOutgoingMessage {
    return nil;
}

-(void)tokenField:(TITokenField *)tokenField didAddToken:(TIToken *)token {
    if (_tokenFieldView.tokenField.tokens) {
        self.contact = ((TSContact*) ((TIToken*)[_tokenFieldView.tokenField.tokens objectAtIndex:0]).representedObject);
        [self startedWritingMessage];
        DLog(@"Contact set to : %@", self.contact.name);
        [self setupThreadWithContact];
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(0);
        dispatch_async( dispatch_get_main_queue(), ^{
            [self.inputToolBarView.textView becomeFirstResponder];
        });
    });
}

#pragma mark UITextViewDelegate (Sending box)

-(BOOL)textViewShouldBeginEditing:(UITextView *)textView {
    if ([textView isEqual:self.inputToolBarView.textView]) {
        
        self.tableView.frame = CGRectMake(0, 0, self.tableView.frame.size.width, self.view.frame.size.height - 44);

    }
    
    return true;
}

-(void) startedWritingMessage {
    // Change frames for editing
    if (_tokenFieldView) {
        [_tokenFieldView setScrollEnabled:FALSE];
        _tokenFieldView.frame = CGRectMake(_tokenFieldView.frame.origin.x, _tokenFieldView.frame.origin.y, _tokenFieldView.frame.size.width, 43);
        self.tableView.frame = CGRectMake(0, 44, self.tableView.frame.size.width, self.tableView.frame.size.height);
        _tokenFieldView.contentSize = CGSizeMake(_tokenFieldView.frame.size.width, 43);
    }
}

-(void) startedEditingReceipients {
    //change frames for
}

@end