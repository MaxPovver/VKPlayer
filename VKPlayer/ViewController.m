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
    bool  lastRequestFromCode = false;
    bool paused = false;
    NSArray  * SCOPE = nil;
    VKAudios* audios = nil;
    AVPlayer* player;
    long currentSONG = -1;

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Do any additional setup after loading the view, typically from a nib.
    SCOPE = @[VK_PER_WALL, VK_PER_AUDIO];
    [VKSdk initializeWithDelegate: self andAppId: @"4697857"];
    [[VKSdk instance] setDelegate: self];
    if ([VKSdk wakeUpSession] && ![[VKSdk getAccessToken] isExpired])
    {
        [self setToken:[VKSdk getAccessToken]];
    }
    else
    {
        [VKSdk authorize:SCOPE];
    }
    //попытаемся вытащить список музычки из настроек
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       NSString* pathTo = [DOCUMENTS
                                           stringByAppendingPathComponent:@"audioList.cache"];
                       NSMutableArray* arr = [[NSMutableArray alloc] initWithContentsOfFile: pathTo];
                       if (arr != nil && [arr count] > 0)
                       {
                           VKAudios* n = [[VKAudios alloc] init];
                           [n setItems: arr];
                           [self updateList: n];
                       }
                   });

}

-(void)setToken:(VKAccessToken* )newToken
{
    token = newToken;
    if (token != nil)
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
    VKCaptchaViewController * vc = [VKCaptchaViewController
                                    captchaControllerWithError: captchaError];
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
    [[[UIAlertView alloc] initWithTitle: nil message: @"Access denied" delegate: nil cancelButtonTitle: @"Ok" otherButtonTitles: nil] show];
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
    [self setToken: newToken];
}

/**
 When reloading music was requested
 */
-(void)shouldReloadMusic
{
    NSDictionary* params = @{
                             @"owner_id": [[self getToken] userId],
                             @"need_user": @"0",
                             @"count": @"0",
                             @"version": @"5.27"
                             };
    VKRequest *request =
    [VKApi requestWithMethod:@"audio.get"
    andParameters:params
    andHttpMethod:@"POST"];
    [request
     executeWithResultBlock:
     ^(VKResponse *response)
    {
        [self updatedMusicList:response];
    }
    errorBlock:
     ^(NSError *error)
    {
        if (error.code != VK_API_ERROR)
        {
            NSLog(@"Unknown error");//[error.vkError.request repeat];
        }
        else
        {
            NSLog(@"VK error: %@", error);
        }
    }];
}

-(void)updatedMusicList:(VKResponse*)newList
{
    VKAudios* l =
        [[VKAudios alloc] initWithDictionary:[newList json]
                                 objectClass:[VKAudio class]];
    if ([l isKindOfClass: [VKAudios class]])
    {
        [self updateList: l];
    }
}

-(void) updateList:(VKAudios*) n
{
   audios = n;
    //сохраним самый актуальный вариант записей в настройки
   dispatch_async(dispatch_get_main_queue(),
                   ^{
                       NSString* pathTo = [DOCUMENTS stringByAppendingPathComponent:@"audioList.cache"];
                       NSData* d = [[NSData  alloc] init];
                       if (![[NSFileManager defaultManager] fileExistsAtPath:pathTo])
                           [[NSFileManager defaultManager]
                            createFileAtPath:pathTo
                            contents: [NSData dataWithBytes: nil length: 0]
                            attributes: nil];
                       NSMutableArray* ar = [n items];
                        if (![ar writeToFile:pathTo atomically:YES])
                            NSLog(@"Failed to cache music list");
                   });
    [self.MusicList reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    if(audios != nil)
        return [audios count];
    else return 0;
}
// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier: @"SongCell"];
    VKAudio* audio = [audios  objectAtIndex: [indexPath item]];
    [cell.textLabel setText: [NSString stringWithFormat:@"%@ – %@", audio.artist, audio.title]];
    int duration = [audio duration].intValue;
    [cell.detailTextLabel setText:
     [NSString stringWithFormat:@"%i:%02i", duration/60, duration%60]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (lastRequestFromCode)
    {
        lastRequestFromCode = false;
        return;
    }
    if (currentSONG != indexPath.item)
    {
        currentSONG = indexPath.item;
        [self playSong];
    }
}

-(void) goToNextSong
{
    currentSONG++;
    [self playSong];
}

-(void) goToPreviousSong
{
    currentSONG--;
    if(currentSONG <0) currentSONG = 0;
    [self playSong];
}

//сообщение, которое получает плеер при смене песни
-(void) playSong
{
    if (currentSONG>audios.count)
    {//если песен больше нет
        currentSONG = 0;//вернемся на начало
        [self.MusicList selectRowAtIndexPath: [NSIndexPath indexPathForRow: currentSONG inSection: 0] animated: YES scrollPosition: UITableViewScrollPositionTop];//и промотаем туда табличку
        return;
    }
    NSLog(@"playing %li", currentSONG);
    VKAudio* song = [audios  objectAtIndex: currentSONG];
     if (player == nil)//при первом вызове создаем объект плеера
     {
         player = [[AVPlayer alloc] initWithURL:[self urlForVKAudio:song]];
         [player play];
         [[AVAudioSession sharedInstance]
            setCategory: AVAudioSessionCategoryPlayback error: nil];//включаем игру в фоне
         [[AVAudioSession sharedInstance] setActive: YES error: nil];
         [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
         [self becomeFirstResponder];
         [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(handleAVPlayerItemDidPlayToEndTimeNotification) name:AVPlayerItemDidPlayToEndTimeNotification object: nil];//включаем срабатывание наблюдателя на завершение проигрывания
     }
     else
     {
         [player replaceCurrentItemWithPlayerItem:
            [[AVPlayerItem alloc] initWithURL: [self urlForVKAudio: song]]];
         [player play];
     }

    
     
}

-(BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) {
                
            case UIEventSubtypeRemoteControlPlay:
                [player play];
                break;
                
            case UIEventSubtypeRemoteControlPause:
                [player pause];
                break;
                
            case UIEventSubtypeRemoteControlPreviousTrack:
                [self goToPreviousSong];
                break;
                
            case UIEventSubtypeRemoteControlNextTrack:
                [self goToNextSong];
                break;
            default:
                break;
        }
    }
}

- (void)handleAVPlayerItemDidPlayToEndTimeNotification
{
    [self goToNextSong];//запустили новую песню
    lastRequestFromCode = true;//перед отправлением сообщения о выборе следующей песни отметим, что этот запрос был не от от реального пользователя, чтобы оно не запускало песню еще раз
    [self.MusicList selectRowAtIndexPath: [NSIndexPath indexPathForRow: currentSONG inSection: 0] animated: YES scrollPosition: UITableViewScrollPositionTop];//промотали играющую песню повыше

}

//вовзращает ссылку на локальный файл, либо, если такого нет, ссылку на мп3
-(NSURL*) urlForVKAudio:(VKAudio*)audio
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL* result = nil;
    NSString* pathTo = [DOCUMENTS stringByAppendingPathComponent: [NSString stringWithFormat: @"%@.mp3", audio.id]];
    //если файл уже сохранен:
    if([fm fileExistsAtPath: pathTo])
    {//вернем его локальное местоположение
        NSLog(@"Already cached");
        result = [NSURL fileURLWithPath: pathTo];
    }
    else
    {//если файл грузится первый раз
        //вернем юрл чтобы плеер сразу играть начал
        result = [NSURL URLWithString: audio.url];
        //и начнем в фоне сохранять его в кеш(да, в два раза больше траффика, но на мой взгляд это не критично)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
        ^{
            NSLog(@"Started saving file %@ – %@ (%@.mp3)...", audio.artist, audio.title, audio.id);
            NSData* data = [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString: audio.url]];

            if(![data writeToFile: pathTo atomically: YES])
                NSLog(@"Failed."); else NSLog(@"Ok.");
         });
    }
    
    return result;
}

- (IBAction)cacheBtnPrsd:(id)sender {
    [self cacheAll: 10];
}


//кеширует все файлы из списка, грузит не более maxConnections песен в единицу времени, все это в фоне
-(void)cacheAll:(int)maxConnections
{
    __block int currentConnections = 0;//разделяемая между всеми потоками перменная счетчика работающих загрузок
    NSFileManager* fm = [NSFileManager defaultManager];
    for (int i=0; i<[[audios items] count];i++)//перебираем все записи
    {
        VKAudio* a = [audios objectAtIndex: i];
        NSString* pathTo = [DOCUMENTS stringByAppendingPathComponent:
                            [NSString stringWithFormat: @"%@.mp3", a.id]];
        if (![fm fileExistsAtPath: pathTo])//если для очередной записи еще нет сохранения в кеше
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),//начнем для нее в фоне загрузку
                           ^{
                               @autoreleasepool {
                                   while (currentConnections >= maxConnections)
                                       //не начинаем загрузку пока подключений слишком много
                                   {
                                       sleep(100);
                                   }
                                   currentConnections++;//добавим к счетчику это подключение
                                   NSLog(@"Connection opened.");
                                   NSLog(@"Started saving file %@ – %@ (%@.mp3)...", a.artist, a.title, a.id);
                                   NSData* data = [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString: a.url]];//грузим из url'a аудизаписи данные
                               
                                   if(![data writeToFile: pathTo atomically: YES])//сохраняя их в файл
                                   {
                                       NSLog(@"Failed.");
                                   }
                                   else
                                   {
                                       NSLog(@"Ok.");
                                   }
                                   NSLog(@"Connection closed");
                                   data = nil;
                                   currentConnections--;//после готовности удалим соединение из счетчика
                               }
                           });
        }
    }
}

- (IBAction)deleteBtnPressed:(id)sender {
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: @"Удалить весь кеш" message: @"Вы точно хотите удалить все сохраненные аудиозаписи?" delegate: self cancelButtonTitle: @"Отмена" otherButtonTitles: @"Удалить", nil];
    [alert show];
}

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
   if (buttonIndex != 0)
    [self uncacheAll];
}

//удаляет всё из кеша
-(void)uncacheAll
{
    int total = 0;
    NSString* pathTo = DOCUMENTS;
    NSArray* files=[[NSFileManager defaultManager] contentsOfDirectoryAtPath: pathTo error: nil];
    for (NSString* filename in files) {
        NSString* file = [pathTo stringByAppendingPathComponent: filename];
        if ([file hasSuffix: @".mp3"])
        {
            if([[NSFileManager defaultManager] removeItemAtPath: file error: nil])
            {
                NSLog(@"Successfully removed %@(%i)", filename, total++);
            }
            else
            {
                NSLog(@"Failed to remove %@", filename);
            }
        }
    }
    NSLog(@"Removed %i files from cache", total);
}
@end
