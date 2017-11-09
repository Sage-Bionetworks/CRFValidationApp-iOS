//
//  CRFHeartRateProcessor.m
//  CRFModuleValidation
//
//  Copyright © 2017 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "CRFHeartRateProcessor.h"

const NSTimeInterval CRFHeartRateSampleRate = 1.0;
const int CRFHeartRateFramesPerSecond = 30;
const int CRFHeartRateSettleSeconds = 3;
const int CRFHeartRateWindowSeconds = 10;
const int CRFHeartRateMinFrameCount = (CRFHeartRateSettleSeconds + CRFHeartRateWindowSeconds) * CRFHeartRateFramesPerSecond;

@implementation CRFHeartRateProcessor

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    // only run if we're not already processing an image
    // this is the image buffer
    CVImageBufferRef cvimgRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // Lock the image buffer
    CVPixelBufferLockBaseAddress(cvimgRef,0);
    
    // access the data
    NSInteger width = CVPixelBufferGetWidth(cvimgRef);
    NSInteger height = CVPixelBufferGetHeight(cvimgRef);
    
    // get the raw image bytes
    uint8_t *buf=(uint8_t *) CVPixelBufferGetBaseAddress(cvimgRef);
    size_t bprow=CVPixelBufferGetBytesPerRow(cvimgRef);
    float r = 0, g = 0, b = 0;
    
    long widthScaleFactor = width / 192;
    long heightScaleFactor = height / 144;
    
    // Get the average rgb values for the entire image.
    for (int y = 0; y < height; y += heightScaleFactor) {
        for (int x = 0; x < width * 4; x += (4 * widthScaleFactor)) {
            r += buf[x + 2];
            g += buf[x + 1];
            b += buf[x];
        }
        buf += bprow;
    }
    r /= 255 * (float)((width * height) / (widthScaleFactor * heightScaleFactor));
    g /= 255 * (float)((width * height) / (widthScaleFactor * heightScaleFactor));
    b /= 255 * (float)((width * height) / (widthScaleFactor * heightScaleFactor));
    
    // Unlock the image buffer
    CVPixelBufferUnlockBaseAddress(cvimgRef,0);
    
    // Create a struct to return the pixel average
    struct CRFPixelSample sample;
    sample.red = (double)r;
    sample.green = (double)g;
    sample.blue = (double)b;
    sample.uptime = (double)(pts.value) / (double)(pts.timescale);
    
    // Alert the delegate
    [self.delegate processor:self didCaptureSample:sample];
}

- (NSInteger)calculateBPMWithDataPoints:(NSArray *)dataPoints {

    // Get a window of data points that is the length of the window we are looking at
    NSUInteger len = CRFHeartRateWindowSeconds * CRFHeartRateFramesPerSecond;
    if (dataPoints.count < len) { return -1; }
    NSArray *inputPoints = [dataPoints subarrayWithRange:NSMakeRange(dataPoints.count - len, len)];
    
    NSArray *bandpassFilteredItems = [self butterworthBandpassFilter:inputPoints];
    NSArray *smoothedBandpassItems = [self medianSmoothing:bandpassFilteredItems];
    int peak = [self medianPeak:smoothedBandpassItems];
    NSInteger heartRate = 60 * CRFHeartRateFramesPerSecond / peak;
    return heartRate;
}

- (int)medianPeak:(NSArray *)inputData
{
    NSMutableArray *peaks = [[NSMutableArray alloc] init];
    int count = 4;
    for (int i = 3; i < inputData.count - 3; i++, count++)
    {
        if (inputData[i] > 0 &&
            [inputData[i] doubleValue] > [inputData[i-1] doubleValue] &&
            [inputData[i] doubleValue] > [inputData[i-2] doubleValue] &&
            [inputData[i] doubleValue] > [inputData[i-3] doubleValue] &&
            [inputData[i] doubleValue] >= [inputData[i+1] doubleValue] &&
            [inputData[i] doubleValue] >= [inputData[i+2] doubleValue] &&
            [inputData[i] doubleValue] >= [inputData[i+3] doubleValue]
            )
        {
            [peaks addObject:@(count)];
            i += 3;
            count = 3;
        }
    }
    if (peaks.count == 0) {
        return -1;
    }
    [peaks setObject:@([peaks[0] integerValue] + count + 3) atIndexedSubscript: 0];
    [peaks sortUsingComparator:^(NSNumber *a, NSNumber *b){
        return [a compare:b];
    }];
    int medianPeak = (int)[peaks[peaks.count * 2 / 3] integerValue];
    return (medianPeak != 0) ? medianPeak : -1;
}

- (NSArray *)butterworthBandpassFilter:(NSArray *)inputData {
    const int NZEROS = 8;
    const int NPOLES = 8;
    static float xv[NZEROS+1], yv[NPOLES+1];
    
    // http://www-users.cs.york.ac.uk/~fisher/cgi-bin/mkfscript
    // Butterworth Bandpass filter
    // 4th order
    // sample rate - varies between possible camera frequencies. Either 30, 60, 120, or 240 FPS
    // corner1 freq. = 0.667 Hz (assuming a minimum heart rate of 40 bpm, 40 beats/60 seconds = 0.667 Hz)
    // corner2 freq. = 4.167 Hz (assuming a maximum heart rate of 250 bpm, 250 beats/60 secods = 4.167 Hz)
    // Bandpass filter was chosen because it removes frequency noise outside of our target range (both higher and lower)
    double dGain = 1.232232910e+02;
    
    NSMutableArray *outputData = [[NSMutableArray alloc] init];
    for (NSNumber *number in inputData) {
        double input = number.doubleValue;
        
        xv[0] = xv[1]; xv[1] = xv[2]; xv[2] = xv[3]; xv[3] = xv[4]; xv[4] = xv[5]; xv[5] = xv[6]; xv[6] = xv[7]; xv[7] = xv[8];
        xv[8] = input / dGain;
        yv[0] = yv[1]; yv[1] = yv[2]; yv[2] = yv[3]; yv[3] = yv[4]; yv[4] = yv[5]; yv[5] = yv[6]; yv[6] = yv[7]; yv[7] = yv[8];
        yv[8] = (xv[0] + xv[8]) - 4 * (xv[2] + xv[6]) + 6 * xv[4]
        + ( -0.1397436053 * yv[0]) + (  1.2948188815 * yv[1])
        + ( -5.4070037946 * yv[2]) + ( 13.2683981280 * yv[3])
        + (-20.9442560520 * yv[4]) + ( 21.7932169160 * yv[5])
        + (-14.5817197500 * yv[6]) + (  5.7161939252 * yv[7]);
        
        [outputData addObject:@(yv[8])];
    }
    
    return outputData;
}

// Smoothed data helps remove outliers that may be caused by interference, finger movement or pressure changes.
// This will only help with small interference changes.
// This also helps keep the data more consistent.
- (NSArray *)medianSmoothing:(NSArray *)inputData {
    NSMutableArray *newData = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < inputData.count; i++) {
        if (i == 0 ||
            i == 1 ||
            i == 2 ||
            i == inputData.count - 1 ||
            i == inputData.count - 2 ||
            i == inputData.count - 3)        {
            [newData addObject:inputData[i]];
        } else {
            NSArray *items = [@[
                                inputData[i-2],
                                inputData[i-1],
                                inputData[i],
                                inputData[i+1],
                                inputData[i+2],
                                ] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
            
            [newData addObject:items[2]];
        }
    }
    
    return newData;
}

@end
