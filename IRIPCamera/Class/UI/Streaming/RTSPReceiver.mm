//
//  RTSPReceiver.m
//  test1
//
//  Created by sniApp on 12/9/13.
//  Copyright (c) 2012年 sniApp. All rights reserved.
//

#import "RTSPReceiver.h"
#import "FrameBaseClass.h"
#import "VideoFrame.h"
#import "AudioFrame.h"
#import "errorCodeDefine.h"
#import "StaticHttpRequest.h"

#define WAITTING_TIME 10.0f

char *tmpfilename;
int frameCount = 0;
int iFlag = 1;
BOOL back = NO;

@interface RTSPReceiver(privatemethod)
- (void) HandleForH264Video:(const uint8_t *)frameData frameDataLength:(int)frameDataLength presentationTime:(struct timeval)presentationTime durationInMicroseconds:(unsigned int)duration;
- (void) HandleForMPEG4Video:(const uint8_t *)frameData frameDataLength:(int)frameDataLength presentationTime:(struct timeval)presentationTime durationInMicroseconds:(unsigned int)duration;
-(void) handleForAudio:(const uint8_t *)frameData frameDataLength:(int)frameDataLength presentationTime:(struct timeval)presentationTime durationInMicroseconds:(unsigned int)duration;
- (void) checkLastReceiveTime;

-(void)handleNotification:(NSNotification *)pNotification;
-(void)handleNotification1:(NSNotification *)pNotification;
@end

@implementation RTSPReceiver
-(void) dealloc
{
    if(p_VideoExtra != NULL)
        free(p_VideoExtra);
    
    if(p_AudioExtra != NULL)
        free(p_AudioExtra);
    
    m_SPSFrame = nil;
    m_PPSFrame = nil;
    
    m_RTSPClient.delegate = nil;
    
    if(m_RTSPClient)
    {
        m_RTSPClient = nil;
    }
}

-(NSUInteger) startConnection
{
    
    m_blnReceiveFirstIFrame = NO;
    self.m_blnPlaySuccess = NO;
    m_VideoCodec = nil;
    m_AudioCodec = nil;
    NSUInteger UintRtn = 0;
    m_VideoWidth = 0;
    m_VideoHeight = 0;
    exit=0;
    
    [self startHandleStream];
    
    if(!m_SPSFrame)
        m_SPSFrame = [[FrameBaseClass alloc] init];
    
    if(!m_PPSFrame)
        m_PPSFrame = [[FrameBaseClass alloc] init];
    
    //    m_strDeviceIP = @"rtsp://192.168.3.100:554/live/ch01_0"; //GM SOHO
    //    m_strDeviceIP = @"rtsp://192.168.1.100:554/live/ch01_0"; //GM SOHO
    //    m_FPS = 30;
    
    m_strURL = [NSString stringWithFormat:@"%@",m_strDeviceIP];
    
    NSURL *tmpURL = [NSURL URLWithString:m_strURL];
    
    if(m_RTSPClient)
        m_RTSPClient = nil;
    
    m_RTSPClient = [[RTSPClientSession alloc] initWithURL:tmpURL delegate:self];
    
    i_AudioExtra = 0;
    p_AudioExtra = NULL;
    
    //    if(!m_blnPlayingAudio)
    //        m_blnPlayingAudio = NO;//default close auction function
    
    do
    {
        if(m_RTSPClient == nil)
        {
            UintRtn = INIT_RTSPCLIENT_SESSION_FAIL;
            break;
        }
        
        if(! [m_RTSPClient setupWithTCP:self.m_blnUseTCP])
            //        if(! [m_RTSPClient setupWithTCP:YES])
        {
            UintRtn = SETUP_RTSPCLIENT_SESSION_FAIL;
            break;
        }
    } while (0);
    
    if(m_RTSPClient)
    {
        m_RTSPClient = nil;
    }
    //    [super stopConnection:back];
    
    return UintRtn;
}

-(BOOL) stopConnection:(BOOL) _blnForever
{
    signal(SIGPIPE, SIG_IGN);
    if(self.m_blnReceiving)
    {
        self.m_blnReceiving = NO;
        
        if(self)
            while (!self.m_blnReceiveFrameFinish) {
                [[StaticHttpRequest sharedInstance] sleepWithTimeInterval:0.1f Function:__func__ Line:__LINE__ File:(char*)__FILE__];
            }
    }
    
    
    [m_RTSPClient shutdownStream];
    //    [[StaticHttpRequest sharedInstance] sleepWithTimeInterval:5.0f];
    back = _blnForever;
    
    [super stopConnection:_blnForever];
    int icount = 0;
    if(self.m_blnPlaySuccess)
    {
        while(m_RTSPClient)
        {
            if(icount >=100)
                break;
            signal(SIGPIPE, SIG_IGN);
            [[StaticHttpRequest sharedInstance] sleepWithTimeInterval:0.01f Function:__func__ Line:__LINE__ File:(char*)__FILE__];
            
            icount++;
        }
    }
    return YES;
}


-(void) stopHandleStream
{
    [self.m_VideoDecoder setShowImageOrNot:NO];
    m_blnProcessData = NO;
    m_blnReceiveFirstIFrame = NO;
}
-(void) startHandleStream
{
    [self.m_VideoDecoder setShowImageOrNot:YES];
    m_blnProcessData = YES;
}


#pragma RTSPClientSession delegate
-(void) tearDownCallback
{
    if(m_RTSPClient)
    {
        m_RTSPClient = nil;
    }
    //    [super stopConnection:back];
}

-(void) videoCallbackByCodec:(NSString *)_codec extraData:(NSData *)_extra
{
    m_VideoCodec = [NSString stringWithFormat:@"%@",_codec];
    
    [self setVideoCodecWithCodecString:_codec];
    if ([m_VideoCodec isEqualToString:@"MP4V-ES"])
    {
        i_VideoExtra = (unsigned int)[_extra length];
        p_VideoExtra = (uint8_t*)malloc([_extra length]);
        memset(p_VideoExtra, 0, i_VideoExtra);
        memcpy(p_VideoExtra, (uint8_t*)[_extra bytes], i_VideoExtra);
        [self setExtraData:[_extra length] extraData:(uint8_t*)[_extra bytes]];
    }
    
    [self.m_VideoDecoder startDecode];
    
}

-(void) audioCallbackByCodec:(NSString *)_codec sampleRate:(int)_sampleRate ch:(int)_ch extraData:(NSData *)_extra
{
    m_AudioCodec = [NSString stringWithFormat:@"%@",_codec];
    //    NSLog(@"%@",m_AudioCodec);
    self.m_SampleRate = _sampleRate;
    self.m_Channel = _ch;
    [self setAudioCodecWithCodecString:m_AudioCodec];
    
    if ([m_AudioCodec isEqualToString:@"MPEG4-GENERIC"])
    {
        i_AudioExtra = (unsigned int)[_extra length];
        p_AudioExtra = (uint8_t*)malloc([_extra length]);
        memset(p_AudioExtra, 0, i_AudioExtra);
        memcpy(p_AudioExtra, (uint8_t*)[_extra bytes], i_AudioExtra);
        [self.m_audioDecoder setExtraData:[_extra length] extraData:(uint8_t*)[_extra bytes]];
        _ch = 1;// for GM SOHO unknow why
    }
    
    [self.m_audioDecoder setAudioDecodeSampleRate:_sampleRate channels:_ch];
}

-(void) startPlayCallback
{
    self.m_blnPlaySuccess = YES;
    if(!self.m_blnReceiving)
    {
        self.m_blnReceiving = YES;
        m_LastReceivetime = [[NSDate date] timeIntervalSince1970];
        
        [NSThread detachNewThreadSelector:@selector(checkLastReceiveTime) toTarget:self withObject:nil];
    }
}

-(void) rtspFailCallbackByErrorCode:(int)_code msg:(NSString *)_strmsg
{
    [self.eventDelegate videoLoss:self  ErrorCode:_code msg:[NSString stringWithFormat:@"%@",_strmsg]];
}


-(void) didReceiveFrame:(const uint8_t *)frameData frameDataLength:(int)frameDataLength presentationTime:(struct timeval)presentationTime durationInMicroseconds:(unsigned int)duration codecName:(NSString *)_codecName

{
    //    NSLog(@"codec:%@ size=%d", _codecName ,frameDataLength);
    self.m_blnReceiveFrameFinish = NO;
    //    if(self.m_blnReceiving && pCount < 60)
    //    return;
    if(self.m_blnReceiving )
    {
        m_LastReceivetime = [[NSDate date] timeIntervalSince1970];
        //        NSLog(@"%@ %d", _codecName ,frameDataLength);
        if([_codecName isEqualToString:@"H264"])
        {
            //                    NSLog(@"%d",frameDataLength);
            [self HandleForH264Video:frameData frameDataLength:frameDataLength presentationTime:presentationTime durationInMicroseconds:duration];
            
        }
        else if ([_codecName isEqualToString:@"MP4V-ES"])
        {
            [self HandleForMPEG4Video:frameData frameDataLength:frameDataLength presentationTime:presentationTime durationInMicroseconds:duration];
        }
        else if ([_codecName isEqualToString:@"JPEG"])
        {
            if(!m_blnReceiveFirstIFrame)
            {
                [eventDelegate connectSuccess:self];//add by robert hsu 20130520
            }
            
            VideoFrame *tmpVideoFrame = [[VideoFrame alloc] init];
            tmpVideoFrame.m_pRawData = (uint8_t *)malloc(frameDataLength);
            tmpVideoFrame.m_uintFrameLenth = frameDataLength;
            memcpy(tmpVideoFrame.m_pRawData, frameData, (int)frameDataLength);
            [self.m_VideoDecoder.m_FrameBuffer addFrameIntoBuffer:tmpVideoFrame];
            tmpVideoFrame = nil;
            m_blnReceiveFirstIFrame = YES;
        }
        else if ([_codecName isEqualToString:@"PCMU"] || [_codecName isEqualToString:@"MPEG4-GENERIC"] || [_codecName isEqualToString:@"PCMA"])
        {
            [self handleForAudio:frameData frameDataLength:frameDataLength presentationTime:presentationTime durationInMicroseconds:duration];
        }
    }
    else if(pCount >= 60)
    {
        //        [eventDelegate videoLoss:self];
    }
    self.m_blnReceiveFrameFinish = YES;
    
}
@end


@implementation RTSPReceiver(privatemethod)

-(void) handleForAudio:(const uint8_t *)frameData frameDataLength:(int)frameDataLength presentationTime:(struct timeval)presentationTime durationInMicroseconds:(unsigned int)duration
{
    
    if(self.m_blnPlayingAudio && iFlag == 1 && self.m_audioDecoder)
        [self.m_audioDecoder decodeAudioFromSource:frameData length:frameDataLength];
    
    //    NSLog(@"self.m_blnPlayingAudio=%d, iFlag=%d", self.m_blnPlayingAudio , iFlag);
}

- (void) HandleForMPEG4Video:(const uint8_t *)frameData frameDataLength:(int)frameDataLength presentationTime:(struct timeval)presentationTime durationInMicroseconds:(unsigned int)duration
{
    //    @synchronized(self.m_VideoDecoder.m_FrameBuffer.self)
    {
        VideoFrame *tmpVideoFrame = [[VideoFrame alloc] init];
        tmpVideoFrame.m_uintFrameLenth = frameDataLength + AV_INPUT_BUFFER_PADDING_SIZE;
        
        //        if(frameData[0] == 0x00 && frameData[1] ==0x00 && frameData[2] == 0x01 && frameData[3] == 0xB6)
        if(frameData[0] == 0x00 && frameData[1] ==0x00 && frameData[2] == 0x01)
        {
            if((frameData[4] & 0x40) == 0x00)
            {
                tmpVideoFrame.m_intFrameType = VIDEO_I_FRAME;
                if(!self.m_blnReceiveFirstIFrame)
                    [self.eventDelegate connectSuccess:self];
                m_blnReceiveFirstIFrame = YES;
                pCount = 0;
            }
            else if ((frameData[4] & 0x40) == 0x40)
            {
                tmpVideoFrame.m_intFrameType = VIDEO_P_FRAME;
                pCount++;
            }
            
            tmpVideoFrame.m_pRawData = (uint8_t *)malloc(frameDataLength + AV_INPUT_BUFFER_PADDING_SIZE);
            tmpVideoFrame.m_intFrameSEQ = pCount;
            memcpy(tmpVideoFrame.m_pRawData, frameData, (int)frameDataLength);
            
            if (m_blnReceiveFirstIFrame)
            {
                [self.m_VideoDecoder.m_FrameBuffer addFrameIntoBuffer:tmpVideoFrame];
            }
            tmpVideoFrame = nil;
        }
    }
}


-(void)HandleForH264Video:(const uint8_t *)frameData frameDataLength:(int)frameDataLength presentationTime:(struct timeval)presentationTime durationInMicroseconds:(unsigned int)duration
{
    //
    ////@synchronized(self.m_VideoDecoder.m_FrameBuffer.self)
    //{
    //    m_FPS = 30;
    //    do {
    ////        if(frameData[0] == 0x65)
    ////            NSLog(@"%02X:%d",frameData[0], frameDataLength);
    //        int iType = frameData[0] & 0x1f;
    //
    //        if(iType == 0X1 && frameData[1] == 0x88)//if nal type is non-idr but frame slice is i or si slice
    //            iType = 0x5;
    //
    //
    //        NSString *tmpType = @"";
    //        VideoFrame *tmpVideoFrame=nil;
    ////        NSLog(@"%02X",iType);
    //        if(iType == 0X7)//SPS
    //        {
    ////            m_blnReceiveFirstIFrame = NO;
    //            tmpType = @"SPS";
    //            if(m_SPSFrame.m_pRawData != NULL)
    //            {
    //                free(m_SPSFrame.m_pRawData);
    //                m_SPSFrame.m_pRawData = NULL;
    //            }
    //
    //            m_SPSFrame.m_intFrameType = SPS_FRAME;
    //            m_SPSFrame.m_uintFrameLenth = frameDataLength + sizeof(m_aryH264StartCode);
    //            m_SPSFrame.m_pRawData = (unsigned char*)malloc(sizeof(m_aryH264StartCode) + frameDataLength);
    //            memcpy(m_SPSFrame.m_pRawData, m_aryH264StartCode, sizeof(m_aryH264StartCode));
    //            memcpy(m_SPSFrame.m_pRawData + sizeof(m_aryH264StartCode), frameData, frameDataLength);
    ////            NSLog(@"[%02X%02X%02X%02X]SPS length = %d", frameData[0], frameData[1], frameData[2], frameData[3],frameDataLength);
    //            [self.m_VideoDecoder setSPSFrame:m_SPSFrame];
    //            break;
    //        }
    //        else if(iType == 0X8)//pps
    //        {
    //            tmpType = @"PPS";
    //            if(m_PPSFrame.m_pRawData != NULL)
    //            {
    //                free(m_PPSFrame.m_pRawData);
    //                m_PPSFrame.m_pRawData = NULL;
    //            }
    //
    //            m_PPSFrame.m_intFrameType = SPS_FRAME;
    //            m_PPSFrame.m_uintFrameLenth = frameDataLength + sizeof(m_aryH264StartCode);
    //            m_PPSFrame.m_pRawData = (unsigned char*)malloc(sizeof(m_aryH264StartCode) + frameDataLength);
    //            memcpy(m_PPSFrame.m_pRawData, m_aryH264StartCode, sizeof(m_aryH264StartCode));
    //            memcpy(m_PPSFrame.m_pRawData + sizeof(m_aryH264StartCode), frameData, frameDataLength);
    ////            NSLog(@"PPS length = %d",frameDataLength);
    //            [self.m_VideoDecoder setPPSFrame:m_PPSFrame];
    //            break;
    //        }
    //        else if(iType == 0X5)//I-Frame
    //        {
    //            if(m_PPSFrame.m_pRawData == NULL || m_SPSFrame.m_pRawData == NULL)
    //                break;
    //
    //            tmpVideoFrame = [[VideoFrame alloc] init];
    //            tmpType = @"I-frame";
    //            pCount = 0;
    //            int iPreheaderTotal = (int)(m_SPSFrame.m_uintFrameLenth + m_PPSFrame.m_uintFrameLenth);
    //
    //            tmpVideoFrame.m_pRawData = (uint8_t*)malloc(frameDataLength + sizeof(m_aryH264StartCode) + iPreheaderTotal );
    //            tmpVideoFrame.m_uintFrameLenth = frameDataLength + sizeof(m_aryH264StartCode) + iPreheaderTotal  ;
    //            tmpVideoFrame.m_intFrameSEQ = pCount;
    //            tmpVideoFrame.m_intFrameType = VIDEO_I_FRAME;
    //            memcpy(tmpVideoFrame.m_pRawData, m_SPSFrame.m_pRawData, (int)m_SPSFrame.m_uintFrameLenth);
    //            memcpy((tmpVideoFrame.m_pRawData + (int)m_SPSFrame.m_uintFrameLenth), m_PPSFrame.m_pRawData, (int)m_PPSFrame.m_uintFrameLenth);
    //
    //            memcpy((tmpVideoFrame.m_pRawData + iPreheaderTotal), m_aryH264StartCode, sizeof(m_aryH264StartCode));
    //            memcpy(tmpVideoFrame.m_pRawData + iPreheaderTotal + sizeof(m_aryH264StartCode) , frameData, frameDataLength);
    //
    //            if(!self.m_blnReceiveFirstIFrame)
    //               [self.eventDelegate connectSuccess:self];
    //
    //            self.m_blnReceiveFirstIFrame = YES;
    //
    //        }
    //        else if(iType == 0X1)//P-Frame
    //        {
    //
    //
    //            pCount++;
    //            if(pCount >= m_FPS)
    //            {
    ////                NSLog(@"fps=%d pCount =%d",m_FPS ,pCount);
    //                break;//add by robert hsu 2013.10.29
    //            }
    //
    //            tmpVideoFrame = [[VideoFrame alloc] init];
    //            tmpType = @"P-frame";
    //
    //
    //            if (!m_blnReceiveFirstIFrame)
    //            {
    //                break;
    //            }
    //
    //            tmpVideoFrame.m_intFrameSEQ = pCount ;
    //            tmpVideoFrame.m_intFrameType = VIDEO_P_FRAME;
    //            tmpVideoFrame.m_uintFrameLenth = sizeof(m_aryH264StartCode) + frameDataLength ;
    //            tmpVideoFrame.m_pRawData = (unsigned char*)malloc(sizeof(m_aryH264StartCode) + frameDataLength );
    //            if(tmpVideoFrame.m_pRawData)
    //            {
    //                memcpy(tmpVideoFrame.m_pRawData, m_aryH264StartCode, sizeof(m_aryH264StartCode));
    //                memcpy(tmpVideoFrame.m_pRawData + sizeof(m_aryH264StartCode), frameData, frameDataLength);
    //            }
    //
    //        }
    //        self.m_blnReceiving = YES;
    //
    //
    //        if(self.m_VideoDecoder.m_FrameBuffer && tmpVideoFrame && frameData && self.m_blnReceiving)
    //            if ([self.m_VideoDecoder.m_FrameBuffer respondsToSelector:@selector(addFrameIntoBuffer:)])
    //            {
    //                tmpVideoFrame.m_uintVideoTimeSec = presentationTime.tv_sec;
    //                tmpVideoFrame.m_uintVideoTimeUSec = presentationTime.tv_usec;
    //
    ////                NSLog(@"pFrame Count = %d",pCount);
    //
    //
    //                [self.m_VideoDecoder.m_FrameBuffer addFrameIntoBuffer:tmpVideoFrame];
    //
    //
    //
    //                int jumpStartCode = sizeof(m_aryH264StartCode);
    //                int iJump = 4;
    //
    //                if(iType == 0X5)
    //                    iJump += m_SPSFrame.m_uintFrameLenth + m_PPSFrame.m_uintFrameLenth ;
    //
    //
    //                if(self.m_blnIsRecording)
    //                {
    ////                    if(iType == 0X5)
    //                    {
    //                        if([self.m_Recorder getVideoExtensionRef] == nil)
    //                        {
    //                            NSData *spsData = nil;
    //                            NSData *ppsData = nil;
    //
    //                            uint8_t *tmpSPS = (uint8_t*)malloc(m_SPSFrame.m_uintFrameLenth  - jumpStartCode);
    //                            uint8_t *tmpPPS = (uint8_t*)malloc(m_PPSFrame.m_uintFrameLenth  - jumpStartCode);
    //                            memcpy(tmpSPS, m_SPSFrame.m_pRawData + jumpStartCode, m_SPSFrame.m_uintFrameLenth - jumpStartCode);
    //                            memcpy(tmpPPS, m_PPSFrame.m_pRawData + jumpStartCode, m_PPSFrame.m_uintFrameLenth - jumpStartCode);
    //                            spsData = [[NSData alloc] initWithBytes:tmpSPS length:m_SPSFrame.m_uintFrameLenth - jumpStartCode];
    //                            ppsData = [[NSData alloc] initWithBytes:tmpPPS length:m_PPSFrame.m_uintFrameLenth - jumpStartCode];
    //                            free(tmpSPS);
    //                            free(tmpPPS);
    //
    //                            [self.m_Recorder setH264VideoExtensionRefBySPS:spsData PPS:ppsData];
    //
    //                            if(spsData)
    //                                spsData = nil;
    //
    //                            if(ppsData)
    //                                ppsData = nil;
    //                        }
    //
    //
    //                        NSData *tmpData ;
    //                        Byte *tmpIframe = (Byte*)malloc(frameDataLength + sizeof(int));
    //                        int tmpSize = 0;
    //
    //                        //video
    //                        tmpSize = CFSwapInt32HostToBig(frameDataLength);
    //                        memcpy(tmpIframe, &tmpSize, sizeof(int));
    //                        memcpy(tmpIframe + sizeof(int), frameData, frameDataLength);
    //                        tmpData = [[NSData alloc] initWithBytes:tmpIframe length:frameDataLength + 4];
    //
    //                        [self.m_Recorder appendVideoToFileWithCodec:m_VideoCodec width:(int)m_VideoWidth height:(int)m_VideoHeight data:tmpData presentationTime:presentationTime isIframe:iType == 0x5];
    //
    //                        free(tmpIframe);
    //                        tmpData = nil;
    //                    }
    //                }
    //            }
    //
    //        tmpVideoFrame = nil;
    //
    //    } while (0);
    //}
    
    
    // For VideoToolBox(NV12)
    m_FPS = 30;
    do {
        //        if(frameData[0] == 0x65)
        //            NSLog(@"%02X:%d",frameData[0], frameDataLength);
        int iType = frameData[0] & 0x1f;
        
        if(iType == 0X1 && frameData[1] == 0x88)//if nal type is non-idr but frame slice is i or si slice
            iType = 0x5;
        
        
        NSString *tmpType = @"";
        VideoFrame *tmpVideoFrame=nil;
        //                    NSLog(@"VideoFrame to nil");
        //        NSLog(@"%02X",iType);
        if(iType == 0X7)//SPS
        {
            //            m_blnReceiveFirstIFrame = NO;
            if(m_SPSFrame.m_pRawData != NULL) // just need once
                break;
            
            tmpType = @"SPS";
            //            if(m_SPSFrame.m_pRawData != NULL)
            //            {
            //                free(m_SPSFrame.m_pRawData);
            //                m_SPSFrame.m_pRawData = NULL;
            //            }
            
            m_SPSFrame.m_intFrameType = SPS_FRAME;
            m_SPSFrame.m_uintFrameLenth = frameDataLength + sizeof(m_aryH264StartCode);
            m_SPSFrame.m_pRawData = (unsigned char*)malloc(sizeof(m_aryH264StartCode) + frameDataLength);
            memcpy(m_SPSFrame.m_pRawData, m_aryH264StartCode, sizeof(m_aryH264StartCode));
            memcpy(m_SPSFrame.m_pRawData + sizeof(m_aryH264StartCode), frameData, frameDataLength);
            //            NSLog(@"[%02X%02X%02X%02X]SPS length = %d", frameData[0], frameData[1], frameData[2], frameData[3],frameDataLength);
            
            //                [self.m_VideoDecoder setExtraData:m_SPSFrame.m_uintFrameLenth extraData:m_SPSFrame.m_pRawData];
            [self.m_VideoDecoder setSPSFrame:m_SPSFrame];
            break;
        }
        else if(iType == 0X8)//pps
        {
            if(m_PPSFrame.m_pRawData != NULL) // just need once
                break;
            tmpType = @"PPS";
            //            if(m_PPSFrame.m_pRawData != NULL)
            //            {
            //                free(m_PPSFrame.m_pRawData);
            //                m_PPSFrame.m_pRawData = NULL;
            //            }
            
            m_PPSFrame.m_intFrameType = SPS_FRAME;
            m_PPSFrame.m_uintFrameLenth = frameDataLength + sizeof(m_aryH264StartCode);
            m_PPSFrame.m_pRawData = (unsigned char*)malloc(sizeof(m_aryH264StartCode) + frameDataLength);
            memcpy(m_PPSFrame.m_pRawData, m_aryH264StartCode, sizeof(m_aryH264StartCode));
            memcpy(m_PPSFrame.m_pRawData + sizeof(m_aryH264StartCode), frameData, frameDataLength);
            //            NSLog(@"PPS length = %d",frameDataLength);
            [self.m_VideoDecoder setPPSFrame:m_PPSFrame];
            break;
        }
        else if(iType == 0X5)//I-Frame
        {
            if(m_PPSFrame.m_pRawData == NULL || m_SPSFrame.m_pRawData == NULL)
                break;
            
            tmpVideoFrame = [[VideoFrame alloc] init];
            tmpType = @"I-frame";
            pCount = 0;
            
            
            //                if(!self.m_blnReceiveFirstIFrame){
            //                    int iPreheaderTotal = (int)(m_SPSFrame.m_uintFrameLenth + m_PPSFrame.m_uintFrameLenth);
            //
            //                    tmpVideoFrame.m_pRawData = (uint8_t*)malloc(frameDataLength + sizeof(m_aryH264StartCode) + iPreheaderTotal );
            //                    tmpVideoFrame.m_uintFrameLenth = frameDataLength + sizeof(m_aryH264StartCode) + iPreheaderTotal  ;
            //                    tmpVideoFrame.m_intFrameSEQ = pCount;
            //                    tmpVideoFrame.m_intFrameType = VIDEO_I_FRAME;
            //                    memcpy(tmpVideoFrame.m_pRawData, m_SPSFrame.m_pRawData, (int)m_SPSFrame.m_uintFrameLenth);
            //                    memcpy((tmpVideoFrame.m_pRawData + (int)m_SPSFrame.m_uintFrameLenth), m_PPSFrame.m_pRawData, (int)m_PPSFrame.m_uintFrameLenth);
            //                    memcpy((tmpVideoFrame.m_pRawData + iPreheaderTotal), m_aryH264StartCode, sizeof(m_aryH264StartCode));
            //                    memcpy(tmpVideoFrame.m_pRawData + iPreheaderTotal + sizeof(m_aryH264StartCode) , frameData, frameDataLength);
            //                }
            //                else{
            //                    int iPreheaderTotal = 0;
            //
            //                    tmpVideoFrame.m_pRawData = (uint8_t*)malloc(frameDataLength + sizeof(m_aryH264StartCode) + iPreheaderTotal );
            //                    tmpVideoFrame.m_uintFrameLenth = frameDataLength + sizeof(m_aryH264StartCode) + iPreheaderTotal  ;
            //                    tmpVideoFrame.m_intFrameSEQ = pCount;
            //                    tmpVideoFrame.m_intFrameType = VIDEO_I_FRAME;
            //                    memcpy((tmpVideoFrame.m_pRawData + iPreheaderTotal), m_aryH264StartCode, sizeof(m_aryH264StartCode));
            //                    memcpy(tmpVideoFrame.m_pRawData + iPreheaderTotal + sizeof(m_aryH264StartCode) , frameData, frameDataLength);
            //                }
            
            
            //For VideoToolBox(NV12), not need to insert the sps and pps into begin of the video frame.
            int iPreheaderTotal = 0;
            
            tmpVideoFrame.m_pRawData = (uint8_t*)malloc(frameDataLength + sizeof(m_aryH264StartCode) + iPreheaderTotal );
            tmpVideoFrame.m_uintFrameLenth = frameDataLength + sizeof(m_aryH264StartCode) + iPreheaderTotal  ;
            tmpVideoFrame.m_intFrameSEQ = pCount;
            tmpVideoFrame.m_intFrameType = VIDEO_I_FRAME;
            memcpy((tmpVideoFrame.m_pRawData + iPreheaderTotal), m_aryH264StartCode, sizeof(m_aryH264StartCode));
            memcpy(tmpVideoFrame.m_pRawData + iPreheaderTotal + sizeof(m_aryH264StartCode) , frameData, frameDataLength);
            
            if(!self.m_blnReceiveFirstIFrame)
                [self.eventDelegate connectSuccess:self];
            
            self.m_blnReceiveFirstIFrame = YES;
            
        }
        else if(iType == 0X1)//P-Frame
        {
            
            
            pCount++;
            
            /* //unknow behavior, it make the some frames lost if(pCount >= m_FPS).
             if(pCount >= m_FPS)
             {
             //                NSLog(@"fps=%d pCount =%d",m_FPS ,pCount);
             break;//add by robert hsu 2013.10.29z
             }
             */
            
            tmpVideoFrame = [[VideoFrame alloc] init];
            tmpType = @"P-frame";
            
            
            if (!m_blnReceiveFirstIFrame)
            {
                break;
            }
            
            tmpVideoFrame.m_intFrameSEQ = pCount ;
            tmpVideoFrame.m_intFrameType = VIDEO_P_FRAME;
            tmpVideoFrame.m_uintFrameLenth = sizeof(m_aryH264StartCode) + frameDataLength ;
            tmpVideoFrame.m_pRawData = (unsigned char*)malloc(sizeof(m_aryH264StartCode) + frameDataLength );
            if(tmpVideoFrame.m_pRawData)
            {
                memcpy(tmpVideoFrame.m_pRawData, m_aryH264StartCode, sizeof(m_aryH264StartCode));
                memcpy(tmpVideoFrame.m_pRawData + sizeof(m_aryH264StartCode), frameData, frameDataLength);
            }
            
        }
        self.m_blnReceiving = YES;
        
        
        if(self.m_VideoDecoder.m_FrameBuffer && tmpVideoFrame && frameData && self.m_blnReceiving)
            if ([self.m_VideoDecoder.m_FrameBuffer respondsToSelector:@selector(addFrameIntoBuffer:)])
            {
                
                tmpVideoFrame.m_uintVideoTimeSec = presentationTime.tv_sec;
                tmpVideoFrame.m_uintVideoTimeUSec = presentationTime.tv_usec;
                
                //                NSLog(@"pFrame Count = %d",pCount);
                
                
                [self.m_VideoDecoder.m_FrameBuffer addFrameIntoBuffer:tmpVideoFrame];
                
                
                
                int jumpStartCode = sizeof(m_aryH264StartCode);
                int iJump = 4;
                
                if(iType == 0X5)
                    iJump += m_SPSFrame.m_uintFrameLenth + m_PPSFrame.m_uintFrameLenth ;
                
                
            }
        
        tmpVideoFrame = nil;
        //            NSLog(@"VideoFrame to nil");
        
    } while (0);
    
    //        pthread_mutex_unlock(&mtx);
    //    dispatch_semaphore_signal(fd_sema);
    
}

- (void) checkLastReceiveTime
{
    NSDate *currentTime;
    CGFloat fWaitingTime = WAITTING_TIME;
    self.m_blnReceiving = YES;
    
    if(!self.m_blnUseTCP)
        fWaitingTime = WAITTING_TIME;
    
    while (self.m_blnReceiving)
    {
        currentTime = [NSDate date];
        //       NSLog(@"last receive time%f",[currentTime timeIntervalSince1970] -m_LastReceivetime);
        CGFloat waittingTime = [currentTime timeIntervalSince1970] -m_LastReceivetime;
        
        if (waittingTime > 1.0) {
            NSLog(@"Waiting Time : %f",waittingTime);
        }
        
        if(waittingTime > fWaitingTime)
        {
            [eventDelegate videoLoss:self  ErrorCode:-99 msg:@"Waiting Time Out."];
            
        }
        [[StaticHttpRequest sharedInstance] sleepWithTimeInterval:0.3f Function:__func__ Line:__LINE__ File:(char*)__FILE__];
    }
}


-(void)handleNotification:(NSNotification *)pNotification
{
    [self stopHandleStream];
    iFlag = 0;
    //    if(m_blnPlayingAudio)
    {
        //        m_blnPlayingAudio = NO;
        
        if(self.m_audioDecoder )
        {
            //        [m_audioDecoder stopDecode];
            self.m_audioDecoder = nil;
            
        }
        else
        {
            NSLog(@"m_audioDecoder error");
        }
    }
    
    
}

-(void)handleNotification1:(NSNotification *)pNotification
{
    [self startHandleStream];
    
    if(!iFlag )
    {
        self.m_audioDecoder = [[AudioDecoder alloc] initAudioDecode];
        
        [self setAudioCodecWithCodecString:m_AudioCodec];
        [self.m_audioDecoder setAudioDecodeSampleRate:m_SampleRate  channels:m_Channel];
        //        m_blnPlayingAudio = YES;
    }
    iFlag = 1;
}
@end