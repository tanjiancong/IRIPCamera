
//
//  VideoDecoder.m
//  test1
//
//  Created by sniApp on 12/9/14.
//  Copyright (c) 2012年 sniApp. All rights reserved.
//

#import "VideoDecoder.h"
#import "errorCodeDefine.h"
#import "StaticHttpRequest.h"
//#import "ALAssetsLibrary+CustomPhotoAlbum.h"
//#import "IRMovieDecoder.h"
//#import "IRMovieGLView.h"
#import "CommonTools.h"
#include "libavcodec/videotoolbox.h"
//#import <IRPlayer/IRPlayer.h>

@interface VideoDecoder(Private)
-(void) startDecoding;
-(UIImage *)imageFromAVPicture:(AVPicture)picture width:(int) width height:(int) height bitsPerPixel:(NSInteger)_bits;
-(void) changeContainerSize;
-(NSUInteger) getCodecByCodecString:(NSString*) strCodec;
-(void) setScaler;
-(void) freeFFMPEG;
-(void) releaseDecoder;
-(CGFloat) presentVideoFrame:(IRFFVideoFrame *) frame;
@end

@implementation VideoDecoder{
    CMVideoFormatDescriptionRef videoFormatDescr;
    VTDecompressionSessionRef session;
    OSStatus status;
    NSData *spsData;
    NSData *ppsData;
    FrameBaseClass* sps, *pps;
    CIContext *temporaryContext;
}
@synthesize m_FrameBuffer ,showView;
@synthesize m_currentOrientation;
@synthesize m_blnChangeOrientation;
@synthesize m_channel ,m_blnDecoding;
@synthesize m_blnShowImage;
@synthesize m_blnStopDecodeing;
@synthesize m_blnRanderFinish;
@synthesize m_blnDecodeFinish;
@synthesize m_ImageHeight;
@synthesize m_ImageWidth;
@synthesize delegate;
-(void) dealloc
{
    
    [self stopDecode];
}

-(id) initDecoder
{
    m_ImageWidth = 0.0f;
    m_ImageHeight = 0.0f;
//    m_ViewWidth = 0.0f;
//    m_ViewHeight = 0.0f;
    
    m_blnDecoding = NO;
    m_decodeContext = NULL;
    m_blnChangeOrientation = NO;
    
    self.library = [[ALAssetsLibrary alloc] init];
    self.m_FrameBuffer = [[VideoFrameBuffer alloc] initWithGop:0];
    m_imgShow = nil;
    
    DisplayJPEG = nil;
    self.m_blnRanderFinish  = YES;
    self.m_blnDecodeFinish = YES;
    return self;
}

-(id) initDecoderWithUIImageView:(IRFFVideoInput *)imageView
{
    showView = imageView;
    return [self initDecoder];
}

-(void) setDisplayUIView:(IRFFVideoInput *)imageView
{
    showView = imageView;
    [self changeContainerSize];
}

-(void) startDecode
{
    m_blnDecoding = YES;
    m_blnShowImage = YES;
    
    //    @autoreleasepool
    {
        [NSThread detachNewThreadSelector:@selector(startDecoding) toTarget:self withObject:nil];
    }
    
    
}

-(void) stopDecode
{
    m_blnDecoding = NO;
    self.delegate = nil;
    
    if(self.m_FrameBuffer)
        [self.m_FrameBuffer close];
    
    m_FrameBuffer = nil;
}

-(NSUInteger) setCodecWithCodecString:(NSString *)strCodec
{
    NSUInteger iRtn = 0;
    NSUInteger iCodec = 0;
    
    AVCodec *tmpAVCodec;
    iCodec = [self getCodecByCodecString:strCodec];
    
    if(iCodec != AV_CODEC_ID_MJPEG)
    {
        do {
            
            if(iCodec == 0)
            {
                iRtn = FIND_VIDEOCOCED_BYSTRING_FAIL;
                break;
            }
            
            //if not import libz.dylib ,avcodec_register_all() will has compile error
            avcodec_register_all();     // if not call , avcodec_find_decoder will get nothing .
            tmpAVCodec = NULL;
            tmpAVCodec = avcodec_find_decoder(iCodec);
            
            if(!tmpAVCodec)
            {
                NSLog(@"init avcodec fail");
                iRtn = FIND_VIDEO_CODEC_FAIL;
                break;
            }
            
            m_decodeContext = avcodec_alloc_context3(tmpAVCodec);
            
            if(m_decodeContext == NULL)
            {
                iRtn = ALLOC_VIDEO_AVCONTEXT_FAIL;
                break;
            }
            
            int iOpenCodec =  -1;
            
            do {
                iOpenCodec =  avcodec_open2(m_decodeContext, tmpAVCodec, nil);
                [[StaticHttpRequest sharedInstance] sleepWithTimeInterval:0.01f Function:__func__ Line:__LINE__ File:__FILE__];
            } while (iOpenCodec == -1);
            
            if (!m_decodeContext->codec) {
                //                NSLog(@"tetset channel[%d] codec[%d]",m_channel ,iCodec);
            }
            
            if(iOpenCodec < 0)
            {
                iRtn = OPEN_VIDEO_AVCODEC_FAIL;
                break;
            }
        } while (0);
        
        m_DecodeFrame = av_frame_alloc();
        
//        [(IRGLView*)showView setDecoder:self]; //set video decoder to GLView
    }
    
    return iRtn;
}

- (IRFFVideoFrame *) handleVFrameImageBuffer:(CVPixelBufferRef)imageBuffer;
{
    int width = (int)CVPixelBufferGetWidth(imageBuffer);
    int height = (int)CVPixelBufferGetHeight(imageBuffer);
    
    IRFFVideoFrame *frame;
//    IRVideoFrameFormat _videoFrameFormat = IRVideoFrameFormatNV12;
    
//    if (_videoFrameFormat == IRVideoFrameFormatNV12) {
        IRFFCVYUVVideoFrame * yuvFrame = [[IRFFCVYUVVideoFrame alloc] initWithAVPixelBuffer:imageBuffer];
        
        frame = yuvFrame;
//    }
    
    m_decodeContext->width = width;
    m_decodeContext->height = height;
    frame.width = m_decodeContext->width;
    frame.height = m_decodeContext->height;

    return frame;
}

-(void)setSPSFrame:(FrameBaseClass*)sps_frame{
//    spsData = nil;
    sps = sps_frame;
    //    [self setExtraData:sps.m_uintFrameLenth extraData:sps.m_pRawData];
    [self setSPSFrameExtraData:sps.m_uintFrameLenth extraData:sps.m_pRawData];
}

-(void)setPPSFrame:(FrameBaseClass*)pps_frame{
//    ppsData = nil;
    pps = pps_frame;
    //    [self setExtraData:sps.m_uintFrameLenth extraData:sps.m_pRawData];
    [self setPPSFrameExtraData:pps.m_uintFrameLenth extraData:pps.m_pRawData];
}

#pragma mark - iOS8 HW decode 相關method

- (void) iOS8HWDecode:(AVCodecContext*)pCodecCtx packet:(AVPacket)packet;
{
    // 1. get SPS,PPS form stream data, and create CMFormatDescription 和 VTDecompressionSession
    if (spsData == nil && ppsData == nil) {
        uint8_t *data = pCodecCtx -> extradata;
        int size = pCodecCtx -> extradata_size;
        NSString *tmp3 = [NSString new];
        for(int i = 0; i < size; i++) {
            NSString *str = [NSString stringWithFormat:@" %.2X",data[i]];
            tmp3 = [tmp3 stringByAppendingString:str];
        }
        
        //        NSLog(@"size ---->>%i",size);
        //        NSLog(@"%@",tmp3);
        
        int startCodeSPSIndex = 0;
        int startCodePPSIndex = 0;
        int spsLength = 0;
        int ppsLength = 0;
        
        for (int i = 0; i < size; i++) {
            if (i >= 3) {
                if (data[i] == 0x01 && data[i-1] == 0x00 && data[i-2] == 0x00 && data[i-3] == 0x00) {
                    if (startCodeSPSIndex == 0) {
                        startCodeSPSIndex = i;
                    }
//                    if (i > startCodeSPSIndex && i+1 < size) {
                    if (i > startCodeSPSIndex) {
                        startCodePPSIndex = i;
                    }
                }
            }
        }
        
        spsLength = startCodePPSIndex - startCodeSPSIndex - 4;
        ppsLength = size - (startCodePPSIndex + 1);
        
        //        NSLog(@"startCodeSPSIndex --> %i",startCodeSPSIndex);
        //        NSLog(@"startCodePPSIndex --> %i",startCodePPSIndex);
        //        NSLog(@"spsLength --> %i",spsLength);
        //        NSLog(@"ppsLength --> %i",ppsLength);
        
        int nalu_type;
        nalu_type = ((uint8_t) data[startCodeSPSIndex + 1] & 0x1F);
        //        NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
        if (nalu_type == 7) {
            spsData = [NSData dataWithBytes:&(data[startCodeSPSIndex + 1]) length: spsLength];
        }
        
        nalu_type = ((uint8_t) data[startCodePPSIndex + 1] & 0x1F);
        //        NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
        if (nalu_type == 8) {
            ppsData = [NSData dataWithBytes:&(data[startCodePPSIndex + 1]) length: ppsLength];
        }
        
        // 2. create  CMFormatDescription
        if (spsData != nil && ppsData != nil) {
            const uint8_t* const parameterSetPointers[2] = { (const uint8_t*)[spsData bytes], (const uint8_t*)[ppsData bytes] };
            const size_t parameterSetSizes[2] = { [spsData length], [ppsData length] };
            status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &videoFormatDescr);
            //            NSLog(@"Found all data for CMVideoFormatDescription. Creation: %@.", (status == noErr) ? @"successfully." : @"failed.");
        }
        
        // 3. create VTDecompressionSession
        VTDecompressionOutputCallbackRecord callback;
        callback.decompressionOutputCallback = didDecompress;
        callback.decompressionOutputRefCon = (__bridge void *)self;
        NSDictionary *destinationImageBufferAttributes =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],(id)kCVPixelBufferOpenGLESCompatibilityKey,[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],(id)kCVPixelBufferPixelFormatTypeKey,nil];
        
        if(session == NULL)
            status = VTDecompressionSessionCreate(kCFAllocatorDefault, videoFormatDescr, NULL, (__bridge CFDictionaryRef)destinationImageBufferAttributes, &callback, &session);
        
        int32_t timeSpan = 90000;
        CMSampleTimingInfo timingInfo;
        timingInfo.presentationTimeStamp = CMTimeMake(0, timeSpan);
        timingInfo.duration =  CMTimeMake(3000, timeSpan);
        timingInfo.decodeTimeStamp = kCMTimeInvalid;
        
//        for(UIView *subView in [showView subviews]){
//            if([subView isKindOfClass:[UIImageView class]]){
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    subView.hidden = YES;
//                });
//            }
//
//        }
    }
    
    int startCodeIndex = 0;
    for (int i = 0; i < 5; i++) {
        if (packet.data[i] == 0x01) {
            startCodeIndex = i;
            break;
        }
    }
    int nalu_type = ((uint8_t)packet.data[startCodeIndex + 1] & 0x1F);
    //    NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
    
    if (nalu_type == 1 || nalu_type == 5) {
        // 4. get NALUnit payload into a CMBlockBuffer,
        CMBlockBufferRef videoBlock = NULL;
        status = CMBlockBufferCreateWithMemoryBlock(NULL, packet.data, packet.size, kCFAllocatorNull, NULL, 0, packet.size, 0, &videoBlock);
        //        NSLog(@"BlockBufferCreation: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");
        
        // 5.  making sure to replace the separator code with a 4 byte length code (the length of the NalUnit including the unit code)
        int reomveHeaderSize = packet.size - 4;
        const uint8_t sourceBytes[] = {(uint8_t)(reomveHeaderSize >> 24), (uint8_t)(reomveHeaderSize >> 16), (uint8_t)(reomveHeaderSize >> 8), (uint8_t)reomveHeaderSize};
        status = CMBlockBufferReplaceDataBytes(sourceBytes, videoBlock, 0, 4);
        //        NSLog(@"BlockBufferReplace: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");
        
        NSString *tmp3 = [NSString new];
        for(int i = 0; i < sizeof(sourceBytes); i++) {
            NSString *str = [NSString stringWithFormat:@" %.2X",sourceBytes[i]];
            tmp3 = [tmp3 stringByAppendingString:str];
        }
        //        NSLog(@"size = %i , 16Byte = %@",reomveHeaderSize,tmp3);
        
        // 6. create a CMSampleBuffer.
        CMSampleBufferRef sbRef = NULL;
        //        int32_t timeSpan = 90000;
        //        CMSampleTimingInfo timingInfo;
        //        timingInfo.presentationTimeStamp = CMTimeMake(0, timeSpan);
        //        timingInfo.duration =  CMTimeMake(3000, timeSpan);
        //        timingInfo.decodeTimeStamp = kCMTimeInvalid;
        const size_t sampleSizeArray[] = {packet.size};
        //        status = CMSampleBufferCreate(kCFAllocatorDefault, videoBlock, true, NULL, NULL, videoFormatDescr, 1, 1, &timingInfo, 1, sampleSizeArray, &sbRef);
        status = CMSampleBufferCreate(kCFAllocatorDefault, videoBlock, true, NULL, NULL, videoFormatDescr, 1, 0, NULL, 1, sampleSizeArray, &sbRef);
        
        //        NSLog(@"SampleBufferCreate: %@", (status == noErr) ? @"successfully." : @"failed.");
        
        // 7. use VTDecompressionSessionDecodeFrame
        VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
        VTDecodeInfoFlags flagOut;
        status = VTDecompressionSessionDecodeFrame(session, sbRef, flags, &sbRef, &flagOut);
        //        NSLog(@"VTDecompressionSessionDecodeFrame: %@", (status == noErr) ? @"successfully." : @"failed.");
        
        CFRelease(videoBlock);
        CFRelease(sbRef);
        
        //        /* Flush in-process frames. */
        //        VTDecompressionSessionFinishDelayedFrames(session);
        //        /* Block until our callback has been called with the last frame. */
        //        VTDecompressionSessionWaitForAsynchronousFrames(session);
        //
        //        /* Clean up. */
        //        VTDecompressionSessionInvalidate(session);
        //        CFRelease(session);
        //        CFRelease(videoFormatDescr);

    }
}

-(void)releaseDecoder{
    /* Clean up. */
    if (session != NULL)
    {
        VTDecompressionSessionInvalidate(session);
        CFRelease(session);
        session = NULL;
    }
    
    if (videoFormatDescr != NULL){
        CFRelease(videoFormatDescr);
        videoFormatDescr = NULL;
    }
    
    if (m_decodeContext)
    {
        // Free scaler
        sws_freeContext(m_ScaleContext);
        m_ScaleContext = NULL;
        
        // Free RGB picture
        avpicture_free(&m_DispPicture);
        
        // Free the YUV frame
        av_free(m_DecodeFrame);
        
        do {
            [[StaticHttpRequest sharedInstance] sleepWithTimeInterval:0.3f*m_channel Function:__func__ Line:__LINE__ File:__FILE__];
            if (m_decodeContext)
            {
                avcodec_close(m_decodeContext);
                avcodec_free_context(&m_decodeContext);
                m_decodeContext = NULL;
            }
            
        } while (m_decodeContext);
        // Close the codec
        
    }
}

#pragma mark - VideoToolBox Decompress Frame CallBack
/*
 This callback gets called everytime the decompresssion session decodes a frame
 */
void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration )
{

    if(!decompressionOutputRefCon)
        return;
    
    __weak __block VideoDecoder *weakSelf = (__bridge VideoDecoder *)decompressionOutputRefCon;;
    
    if(!weakSelf.m_blnDecoding)
        return;
    
    if (status != noErr || !imageBuffer) {
        NSLog(@"Error decompresssing frame at time: %.3f error: %d infoFlags: %u", (float)presentationTimeStamp.value/presentationTimeStamp.timescale, (int)status, (unsigned int)infoFlags);
        return;
    }
    
    [weakSelf presentVideoFrame:[weakSelf handleVFrameImageBuffer:imageBuffer]];
    if (imageBuffer != NULL) {
        CVPixelBufferRetain(imageBuffer);
    }
}

-(void) setExtraData:(NSInteger) _iLen extraData:(uint8_t *) _extradata
{
    if(m_decodeContext && _extradata && (_iLen > 0))
    {
        NSLog(@"%d %s",_iLen ,_extradata);
        m_decodeContext->extradata_size = _iLen;
        m_decodeContext->extradata = (uint8_t *)malloc(_iLen + AV_INPUT_BUFFER_PADDING_SIZE);
        
        if(m_decodeContext->extradata)
        {
            memcpy(m_decodeContext->extradata, _extradata, _iLen);
            memset(&((uint8_t*)m_decodeContext->extradata)[_iLen], 0, AV_INPUT_BUFFER_PADDING_SIZE);
        }
        
        uint8_t *data = m_decodeContext -> extradata;
        int size = m_decodeContext -> extradata_size;
        NSString *tmp3 = [NSString new];
        for(int i = 0; i < size; i++) {
            NSString *str = [NSString stringWithFormat:@" %.2X",data[i]];
            tmp3 = [tmp3 stringByAppendingString:str];
        }
        
        NSLog(@"%@",tmp3);
    }
}

-(void) setSPSFrameExtraData:(NSInteger) _iLen extraData:(uint8_t *) _extradata
{
    if(m_decodeContext && _extradata && (_iLen > 0))
    {
        NSLog(@"%d %s",_iLen ,_extradata);
        m_decodeContext->extradata_size = _iLen;
        m_decodeContext->extradata = (uint8_t *)malloc(_iLen);
        
        if(m_decodeContext->extradata)
        {
            memcpy(m_decodeContext->extradata, _extradata, _iLen);
        }
        
        uint8_t *data = m_decodeContext -> extradata;
        int size = m_decodeContext -> extradata_size;
        NSString *tmp3 = [NSString new];
        for(int i = 0; i < size; i++) {
            NSString *str = [NSString stringWithFormat:@" %.2X",data[i]];
            tmp3 = [tmp3 stringByAppendingString:str];
        }
        
        NSLog(@"%@",tmp3);
    }
}

-(void) setPPSFrameExtraData:(NSInteger) _iLen extraData:(uint8_t *) _extradata
{
    if(m_decodeContext && _extradata && (_iLen > 0))
    {
        NSLog(@"%d %s",_iLen ,_extradata);
        NSInteger l = m_decodeContext->extradata_size;
        uint8_t * old_data = (uint8_t *)malloc(m_decodeContext->extradata_size);
        memcpy(old_data, m_decodeContext->extradata, l);
        m_decodeContext->extradata_size = _iLen + m_decodeContext->extradata_size;
        m_decodeContext->extradata = (uint8_t *)malloc(m_decodeContext->extradata_size + AV_INPUT_BUFFER_PADDING_SIZE);
        
        if(m_decodeContext->extradata)
        {
            memcpy(m_decodeContext->extradata, old_data, l);
            memcpy(m_decodeContext->extradata  + l, _extradata, _iLen);
            memset(&((uint8_t*)m_decodeContext->extradata)[_iLen + l], 0, AV_INPUT_BUFFER_PADDING_SIZE);
        }
        
        uint8_t *data = m_decodeContext -> extradata;
        int size = m_decodeContext -> extradata_size;
        NSString *tmp3 = [NSString new];
        for(int i = 0; i < size; i++) {
            NSString *str = [NSString stringWithFormat:@" %.2X",data[i]];
            tmp3 = [tmp3 stringByAppendingString:str];
        }
        
        NSLog(@"%@",tmp3);
    }
}

-(void) setChannel:(NSInteger) _ch
{
    m_channel = _ch;
    self.m_FrameBuffer.m_Channel = _ch;
}

-(void) setShowImageOrNot:(BOOL) _blnShow
{
    m_blnShowImage = _blnShow;
}
@end


@implementation VideoDecoder(Private)
-(NSUInteger) getCodecByCodecString:(NSString *)strCodec
{
    NSUInteger iRtn = 0;
    
    if([strCodec isEqualToString:@"MPV"])
    {
        iRtn = AV_CODEC_ID_MPEG2VIDEO;
    }
    else if ([strCodec isEqualToString:@"H264"])
    {
        iRtn = AV_CODEC_ID_H264;
    }
    else if ([strCodec isEqualToString:@"MP4V-ES"])
    {
        iRtn = AV_CODEC_ID_MPEG4;
    }
    else if ([strCodec isEqualToString:@"JPEG"])
    {
        iRtn = AV_CODEC_ID_MJPEG;
    }
    
    //    NSLog(@"channel:%d[%@] codec id=[%d]",m_channel ,strCodec ,iRtn);
    return iRtn;
}



-(void) startDecoding
{
    int i_got_picture = 0;
    m_blnStopDecodeing = NO;
    //               NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    while (m_blnDecoding)
    {
        @autoreleasepool
        {
//            if( self.m_FrameBuffer && m_blnShowImage)
            if(m_blnShowImage && self.m_FrameBuffer)
            {
                VideoFrame *tmpFrame = (VideoFrame*)[self.m_FrameBuffer getOneFrame] ;
                
                if(tmpFrame != nil && tmpFrame.m_uintFrameLenth > 0)
                {
                    if(showView){
                        
                    }
                    
                    if(m_decodeContext)
                    {
                        
                        double decodeS = [NSDate timeIntervalSinceReferenceDate] * 1000;
                        AVPacket tmpPacket;         //source frame
                        av_init_packet(&tmpPacket);
                        
                        if(tmpFrame.m_pRawData != NULL)
                        {
                            self.m_blnDecodeFinish = NO;
                            tmpPacket.data = tmpFrame.m_pRawData;
                            tmpPacket.size = tmpFrame.m_uintFrameLenth;
                    
                            [self iOS8HWDecode:m_decodeContext packet:tmpPacket];
                            
                            int iRet = 1;
                            if(iRet > 0)
                            {
//                                CGSize videoSize = CGSizeMake(showView.bounds.size.width, showView.bounds.size.height);
                                
                                if(m_blnChangeOrientation)
                                {
//                                    CGRect tmpRect = showView.frame;
//                                    videoSize = CGSizeMake(tmpRect.size.height, tmpRect.size.width);
                                    [self changeContainerSize];
                                    m_blnChangeOrientation = NO;
                                }
                                
                                if(m_ImageWidth != m_decodeContext->width || m_ImageHeight != m_decodeContext->height)
                                {
//                                    if (m_ImageHeight != 0) {
//                                        NSLog(@"ch[%d] m_Image[w,h]=[%f ,%f] m_decodeContext[w,h]=[%d,%d]",m_channel,m_ImageWidth ,m_ImageHeight
//                                              ,m_decodeContext->width ,m_decodeContext->height);
//                                        free(tmpFrame.m_pRawData);
//                                        tmpFrame.m_pRawData = NULL;
//                                        
//                                        tmpFrame = nil;
//                                        continue;
//                                    }
//                                    else
                                    {
                                        m_ImageWidth = m_decodeContext->width;
                                        m_ImageHeight = m_decodeContext->height;
                                        
                                        NSLog(@"ch[%d] m_Image[w,h]=[%f ,%f] m_decodeContext[w,h]=[%d,%d]",m_channel,m_ImageWidth ,m_ImageHeight,m_decodeContext->width ,m_decodeContext->height);
                                        
                                        if(self.delegate)
                                        {
                                            [self.delegate videoChangeWidth:m_ImageWidth height:m_ImageHeight];
                                            [self setScaler];
                                        }
                                        else
                                            break;
                                    }
                                    
                                    
                                    
                                }
                                
//                                [self presentFrame:[self handleVideoFrame:m_DecodeFrame]]; //use opengl render
                                
                            }
                            else
                            {
                                NSLog(@"error code = %d",iRet);
                            }
                        }
                        
                        
                        
                        if(&tmpPacket)
                            av_free_packet(&tmpPacket);
                        
                        self.m_blnDecodeFinish = YES;
                    }
                    else
                    {
                        
                        if(DisplayJPEG != nil)
                        {
                            DisplayJPEG = nil;
                        }
                    }

                    tmpFrame = nil;
                }
                else
                {
                    if(m_blnDecoding)
                    {
                        //2015/1/13
                        //[[StaticHttpRequest sharedInstance] sleepWithTimeInterval:1.0f/100.0f Function:__func__ Line:__LINE__ File:__FILE__];
                    }
                    
                }
                
            }//end of if(m_decodeContext != NULL && self.m_FrameBuffer)
        }//end of @autoreleasepool
        
    }//end of while(m_blnDecoding)
    //NSLog(@"stop***************[%d]",self.m_channel);
    
    [self freeFFMPEG];
    [self releaseDecoder];
//    [showView setImage:[UIImage imageNamed:@"landscape_1.png"]];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        showView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"landscape_1.png"]];
//        UIImage *imageLoadingStream = [UIImage imageNamed:@"landscape_1.png"];
//        imageLoadingStream = [CommonTools imageWithImage:imageLoadingStream scaledToSize:[self imageSizeAfterAspectFit:showView originImageSize:imageLoadingStream.size]];
//        showView.backgroundColor = [UIColor colorWithPatternImage:imageLoadingStream];
//    });
    m_blnStopDecodeing = YES;
    
}


-(UIImage *)imageFromAVPicture:(AVPicture)picture width:(int) width height:(int) height bitsPerPixel:(NSInteger)_bits
{
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, picture.data[0], picture.linesize[0] * height, kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    int bitsPreComponent = 8;
    int bitPerPixel = _bits * bitsPreComponent;
    
    int bytesPerRow = _bits * width;
    
    CGImageRef cgImage = CGImageCreate(width, height, bitsPreComponent, bitPerPixel,  bytesPerRow, colorSpace, bitmapInfo, provider, NULL, NO, kCGRenderingIntentDefault);
    
    UIImage *rtnImage = nil;
    rtnImage = [UIImage imageWithCGImage:cgImage];
    
    
    CGColorSpaceRelease(colorSpace);
    
    
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    
    return rtnImage;
    
}

-(void) changeContainerSize
{
//    m_ViewWidth = showView.frame.size.width;
//    m_ViewHeight = showView.frame.size.height;
}

-(void) setScaler
{
    //this code made app crash if use VideoToolBox(NV12)
//    // Release old picture and scaler
//    avpicture_free(&m_DispPicture);
//    sws_freeContext(m_ScaleContext);
//    
//    // Setup scaler
//    static int sws_flags = SWS_BILINEAR;
//    avpicture_alloc(&m_DispPicture, PIX_FMT_RGB24, m_decodeContext->width, m_decodeContext->height);
//    m_ScaleContext = sws_getContext(m_decodeContext->width
//                                    , m_decodeContext->height
//                                    , m_decodeContext->pix_fmt
//                                    , m_decodeContext->width
//                                    , m_decodeContext->height
//                                    , PIX_FMT_RGB24, sws_flags, NULL, NULL, NULL);
}

-(void) freeFFMPEG
{
    //    avpicture_free(&m_DispPicture);
    //    if(m_DecodeFrame)
    //        av_free(m_DecodeFrame);
    //    sws_freeContext(m_ScaleContext);
    //    
    //    
    //    if(m_decodeContext)
    //    {
    //        do
    //        {
    ////                        [NSThread sleepWithTimeInterval:5.1f*m_channel Function:__func__ Line:__LINE__ File:__FILE__];
    //            NSLog(@"channel:%d stop codec",m_channel);
    //            
    ////            if(avcodec_is_open(m_decodeContext))
    //                avcodec_close(m_decodeContext);
    //            
    //
    //        }//keep try stop avcodec until stop codec
    ////        while (avcodec_is_open(m_decodeContext));
    //          while (0);
    //
    //    }
    //    
    
}

#pragma mark - use opengl render

static UInt8 * copyFrameData(UInt8 *src, int linesize, int width, int height)
{
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return dst;
}

- (IRFFVideoFrame *) handleVideoFrame:(AVFrame *) _videoFrame;
{
    if (!_videoFrame->data[0])
        return nil;
    
    IRFFVideoFrame *frame;
//    IRPixelFormat _videoFrameFormat = YUV_IRPixelFormat;
    
//    if (_videoFrameFormat == IRVideoFrameFormatYUV) {
        
        IRFFAVYUVVideoFrame * yuvFrame = [[IRFFAVYUVVideoFrame alloc] init];
        
        yuvFrame.luma = copyFrameData(_videoFrame->data[0],
                                      _videoFrame->linesize[0],
                                      m_decodeContext->width,
                                      m_decodeContext->height);
        
        yuvFrame.chromaB = copyFrameData(_videoFrame->data[1],
                                         _videoFrame->linesize[1],
                                         m_decodeContext->width / 2,
                                         m_decodeContext->height / 2);
        
        yuvFrame.chromaR = copyFrameData(_videoFrame->data[2],
                                         _videoFrame->linesize[2],
                                         m_decodeContext->width / 2,
                                         m_decodeContext->height / 2);
        
        frame = yuvFrame;
        
//    }
    
    frame.width = m_decodeContext->width;
    frame.height = m_decodeContext->height;
    
    return frame;
}

- (CGFloat) presentFrame:(IRFFVideoFrame*) frame
{
    CGFloat interval = 0;
    
    if (frame)
        interval = [self presentVideoFrame:frame];
    
    return interval;
}

- (CGFloat) presentVideoFrame: (IRFFVideoFrame *) frame
{
    //    dispatch_sync(dispatch_get_main_queue(), ^{
    [showView updateFrame:frame];
    //    });
    
//    return frame.duration;
    return 0;
}

//- (NSUInteger) frameWidth
//{
//    return m_decodeContext ? m_decodeContext->width : 0;
//}
//
//- (NSUInteger) frameHeight
//{
//    return m_decodeContext ? m_decodeContext->height : 0;
//}

@end
