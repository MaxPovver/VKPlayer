//
//  ViewController.m
//  VKPlayer
//
//  Created by Максим Чистов on 25.12.14.
//  Copyright (c) 2014 Максим Чистов. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#define DOCUMENTS [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITableView *MusicList;

@end

@implementation ViewController
    VKAccessToken* token;
    NSArray  * SCOPE = nil;
VKAudios* audios = nil;
AVPlayer* player;
    long currentSONG = -1;
- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view, typically from a nib.
    SCOPE = @[ VK_PER_WALL, VK_PER_AUDIO];
    [VKSdk initializeWithDelegate:self andAppId:@"4697857"];
    [[VKSdk instance] setDelegate:self];
    if ([VKSdk wakeUpSession])
    {
        [self setToken:[VKSdk getAccessToken]];
    } else { [VKSdk authorize:SCOPE]; }
}

-(void)setToken:(VKAccessToken* )newToken
{
    token = newToken;
    if(token!=nil)
    {
        [self shouldReloadMusic];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(VKAccessToken*)getToken
{
    return token;
}
/**
 Calls when user must perform captcha-check
 @param captchaError error returned from API. You can load captcha image from <b>captchaImg</b> property.
 After user answered current captcha, call answerCaptcha: method with user entered answer.
 */
- (void)vkSdkNeedCaptchaEnter:(VKError *)captchaError
{
    VKCaptchaViewController * vc = [VKCaptchaViewController captchaControllerWithError:captchaError];
    [vc presentIn:self];
}

/**
 Notifies delegate about existing token has expired
 @param expiredToken old token that has expired
 */
- (void)vkSdkTokenHasExpired:(VKAccessToken *)expiredToken
{
    if ([self getToken] == expiredToken) {
        [self setToken: nil];
    }
}

/**
 Notifies delegate about user authorization cancelation
 @param authorizationError error that describes authorization error
 */
- (void)vkSdkUserDeniedAccess:(VKError *)authorizationError
{
    NSLog(@"AUTH ERROR");
    [[[UIAlertView alloc] initWithTitle:nil message:@"Access denied" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
}

/**
 Pass view controller that should be presented to user. Usually, it's an authorization window
 @param controller view controller that must be shown to user
 */
- (void)vkSdkShouldPresentViewController:(UIViewController *)controller
{
    
}

/**
 Notifies delegate about receiving new access token
 @param newToken new token for API requests
 */
- (void)vkSdkReceivedNewToken:(VKAccessToken *)newToken
{
    [self setToken:newToken];
}
/**
 When reloading music was requested
 */
-(void)shouldReloadMusic
{
    //TODO: кеширование списка музона довести до ума
    //сначала подгрузим текущий закешированный список , если он есть
   /* NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
    VKResponse* r = [[VKResponse alloc] init];//пытаемся вытащить файл из настроек
    NSString* s=[d stringForKey:@"musicjson"];
    if ( s!=nil)//если что-то там лежит
    {
        [r setResponseString:s];
        [self updatedMusicList:r];//пытаемся его показать
    }*/
    //загрузим его в таблицу, теперь можно слушать кешированную музыку
    //а теперь грузим список из интернета
    NSDictionary* params = @{
                             @"owner_id":[[self getToken] userId],
                             @"need_user":@"0",
                             @"count":@"0",
                             @"version":@"5.27"
                             };
    VKRequest *request =
    [VKApi requestWithMethod:@"audio.get"
    andParameters:params
    andHttpMethod:@"POST"];
    [request executeWithResultBlock: ^(VKResponse *response) {
        /*[d  setObject:[response responseString] forKey:@"musicjson"];//закидываем новый список в настройки
        [d synchronize];//сохраним настройки
        if (response != r) //если ничего не поменялось, не будем раздражать пользователя обновлениями*/
        [self updatedMusicList:response];//NSLog(@"Result: %@", response);
    } errorBlock: ^(NSError *error) {
        if (error.code != VK_API_ERROR) {
            NSLog(@"Unknown error");//[error.vkError.request repeat];
        }
        else {
            NSLog(@"VK error: %@", error);
        }
    }];
}
-(void)updatedMusicList:(VKResponse*)newList
{
    VKAudios* l =
        [[VKAudios alloc] initWithDictionary:[newList json]
                                 objectClass:[VKAudio class]];
    if ( [l isKindOfClass:[VKAudios class]]) {
        [self updateList:l];
    }
}
-(void) updateList:(VKAudios*) n
{
    audios=n;
    [self.MusicList reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    if( audios!=nil)
        return [audios count];
    else return 0;
}
// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"SongCell"];
    VKAudio* audio = [audios  objectAtIndex:[indexPath item] ];
    [cell.textLabel setText:[NSString stringWithFormat:@"%@ – %@",audio.artist,audio.title]];
    int dur = [audio duration].intValue;
    [cell.detailTextLabel setText:
     [NSString stringWithFormat:@"%i:%02i",dur/60,dur%60]];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (currentSONG!=indexPath.item) {
        currentSONG = indexPath.item;
        [self playSong];
    }
}

-(void) goToNextSong
{
    currentSONG++;
    [self playSong];
}
//требует проиграт текущую песню
-(void) playSong
{
    if (currentSONG>audios.count) {//если песен больше нет
        currentSONG = 0;//вернемся на начало
        [self.MusicList selectRowAtIndexPath:[NSIndexPath indexPathForRow:currentSONG inSection:0] animated:YES scrollPosition:UITableViewScrollPositionTop];//и промотаем туда табличку
        return;
    }
    NSLog(@"playing %i",currentSONG);
    VKAudio* song = [audios  objectAtIndex:currentSONG ];
    player =  [[AVPlayer alloc] initWithURL:[self urlForVKAudio:song]];
    [player play];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAVPlayerItemDidPlayToEndTimeNotification) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
}
- (void)handleAVPlayerItemDidPlayToEndTimeNotification
{
    [self goToNextSong];//запустили новую песню
    [self.MusicList selectRowAtIndexPath:[NSIndexPath indexPathForRow:currentSONG inSection:0] animated:YES scrollPosition:UITableViewScrollPositionTop];//промотали играющую песню повыше

}

//вовзращает ссылку на локальный файл, либо, если такого нет, ссылку на мп3
-(NSURL*) urlForVKAudio:(VKAudio*)audio
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL* result = nil;
    NSString* pathTo = [DOCUMENTS stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3",audio.id]];
    //если файл уже сохранен:
    if([fm fileExistsAtPath:pathTo])
    {//вернем его локальное местоположение
        NSLog(@"Already cached");
        result = [NSURL fileURLWithPath:pathTo];
    }
    else
    {//если файл грузится первый раз
        //вернем юрл чтобы плеер сразу играть начал
        result = [NSURL URLWithString:audio.url];
        //и начнем в фоне сохранять его в кеш

        dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
        ^{
            NSLog(@"Started saving file...");
            NSData* data = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:audio.url]];

            if(![data writeToFile:pathTo atomically:YES])
                NSLog(@"Failed."); else NSLog(@"Ok.");
        });
    }
    
    return result;
}
-(void)cacheAll:(int)maxConnections
{
    
}
@end
