/*
 * Copyright (c) 2006, Technische Universitaet Berlin
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 * - Neither the name of the Technische Universitaet Berlin nor the names
 *   of its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * - Revision -------------------------------------------------------------
 * $Revision: 1.4 $
 * $Date: 2006-12-12 18:22:49 $
 * @author: Jan Hauer
 * ========================================================================
 */

/**
 * 
 * Sensing demo application. See README.txt file in this directory for usage
 * instructions and have a look at tinyos-2.x/doc/html/tutorial/lesson5.html
 * for a general tutorial on sensing in TinyOS.
 *
 * @author Jan Hauer
 */

#include "Timer.h"
#include "blip_printf.h"
 #include <lib6lowpan/ip.h>

module SenseC
{
  uses {
    interface Boot;
    interface Leds;
    interface Timer<TMilli>;
    interface Timer<TMilli> as reply;
    interface Read<uint16_t>;
    interface ShellCommand  as ReadCmd;
    interface SplitControl as RadioControl;

  }
}
implementation
{
  // sampling frequency in binary milliseconds
  #define SAMPLING_FREQUENCY 16 //24
  //#define SERIAL_FREQUENCY 20
  
  /*Main*/
  volatile uint16_t BPM;                   // used to hold the pulse rate
  volatile uint16_t Signal;                // holds the incoming raw data
  volatile uint16_t IBI = 600;             // holds the time between beats, must be seeded! 
  volatile bool Pulse = FALSE;        // true when pulse wave is high, false when it's low
  volatile bool QS = TRUE;            // becomes true when we find a beat.


  /*Timer part*/
  volatile int rate[10];                              // array to hold last ten IBI values
  volatile unsigned long sampleCounter = 0;           // used to determine pulse timing
  volatile unsigned long lastBeatTime = 0;            // used to find IBI
  volatile int P =2048;//512;                         // used to find peak in pulse wave, seeded
  volatile int T = 2048;//512;                        // used to find trough in pulse wave, seeded
  volatile int thresh = 2048;//512;                   // used to find instant moment of heart beat, seeded
  volatile int amp = 100;                             // used to hold amplitude of pulse waveform, seeded
  volatile bool firstBeat = TRUE;                     // used to seed rate array so we startup with reasonable BPM
  volatile bool secondBeat = FALSE;                   // used to seed rate array so we startup with reasonable BPM
  int N;
  int i=0;
  uint16_t runningTotal=0;

  event void Boot.booted() {
    call Timer.startPeriodic(SAMPLING_FREQUENCY);
    //call SerialSender.startPeriodic(SERIAL_FREQUENCY);
    call RadioControl.start();
  }

  event void RadioControl.stopDone(error_t e){}
  event void RadioControl.startDone(error_t e){}

  event void Timer.fired() 
  {
    call Read.read();
  }

  event void Read.readDone(error_t result, uint16_t data) 
  {    
      atomic {                                      //no interrupt while doing this part 
        Signal = data;                              // read the Pulse Sensor 
        sampleCounter += 16;                        // keep track of the time in mS with this variable
        N = sampleCounter - lastBeatTime;           // monitor the time since the last beat to avoid noise

        //  find the peak and trough of the pulse wave
        if(Signal < thresh && N > (IBI/5)*3){       // avoid dichrotic noise by waiting 3/5 of last IBI
          if (Signal < T){                          // T is the trough
            T = Signal;                             // keep track of lowest point in pulse wave 
          }
        }

        if(Signal > thresh && Signal > P){          // thresh condition helps avoid noise
          P = Signal;                               // P is the peak
        }                                           // keep track of highest point in pulse wave
        //  NOW IT'S TIME TO LOOK FOR THE HEART BEAT
        // signal surges up in value every time there is a pulse
        if (N > 250){                               // avoid high frequency noise
          if ( (Signal > thresh) && (Pulse == FALSE) && (N > (IBI/5)*3) ){        
            Pulse = TRUE;                           // set the Pulse flag when we think there is a pulse
            call Leds.led1On();                     // turn on pin 13 LED
            IBI = sampleCounter - lastBeatTime;     // measure time between beats in mS
            lastBeatTime = sampleCounter;           // keep track of time for next pulse

            if(secondBeat){                         // if this is the second beat, if secondBeat == TRUE
              secondBeat = FALSE;                   // clear secondBeat flag
              for( i=0; i<=9; i++){                 // seed the running total to get a realisitic BPM at startup
                rate[i] = IBI;                      
              }
            }

            if(firstBeat){                          // if it's the first time we found a beat, if firstBeat == TRUE
              firstBeat = FALSE;                    // clear firstBeat flag
              secondBeat = TRUE;                    // set the second beat flag
              //sei();                              // enable interrupts again
              return;                               // IBI value is unreliable so discard it
            }   


            // keep a running total of the last 10 IBI values
            runningTotal = 0;                       // clear the runningTotal variable    

            for(i=0; i<=8; i++){                    // shift data in the rate array
              rate[i] = rate[i+1];                  // and drop the oldest IBI value 
              runningTotal += rate[i];              // add up the 9 oldest IBI values
            }

            rate[9] = IBI;                          // add the latest IBI to the rate array
            runningTotal += rate[9];                // add the latest IBI to runningTotal
            runningTotal /= 10;                     // average the last 10 IBI values 
            BPM = 60000/runningTotal;               // how many beats can fit into a minute? that's BPM! //60000
            QS = TRUE;                              // set Quantified Self flag 
         
          }                       
        }

        if (Signal < thresh && Pulse == TRUE){      // when the values are going down, the beat is over
          call Leds.led1Off();                      // turn off pin 13 LED
          Pulse = FALSE;                            // reset the Pulse flag so we can do it again
          amp = P - T;                              // get amplitude of the pulse wave
          thresh = amp/2 + T;                       // set thresh at 50% of the amplitude
          P = thresh;                               // reset these for next time
          T = thresh;
        }

        if (N > 2500){                              // if 2.5 seconds go by without a beat
          thresh = 2048;//512;                      // set thresh default
          P =  2048;//512;                          // set P default
          T =  2048;//512;                          // set T default
          lastBeatTime = sampleCounter;             // bring the lastBeatTime up to date        
          firstBeat = TRUE;                         // set these to avoid noise
          secondBeat = FALSE;                       // when we get the heartbeat back
        }



        /*Atomic ends here*/
      }

  }
   event char* ReadCmd.eval(int argc, char** argv) {
    char *reply_buf = call ReadCmd.getBuffer(128);
    int len = 0;
    len=sprintf(reply_buf,"Beats per minute :%d \n",BPM);
    return reply_buf;
  }
  /*event void reply.fired()
  {
    char *reply_buf = call ReadCmd.getBuffer(128);
    int len = 0;
    len=sprintf(reply_buf,"Beats per minute :%d \n",BPM);
    return reply_buf;

  }*/
}
