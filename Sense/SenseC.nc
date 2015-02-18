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
    interface Timer<TMilli> as calib;
    interface Timer<TMilli> as calib_5s;
    interface Timer<TMilli> as calib_1s;
    interface Timer<TMilli> as game_timer;
    interface Timer<TMilli> as compete_timer;


    
    interface Read<uint16_t>;
    interface ShellCommand  as ReadCmd;
    interface ShellCommand  as SyncCmd; 
    interface ShellCommand  as StopCmd;
    interface UDP as multicastUdp;
    interface UDP as multicastUdp_gameover;
    interface SplitControl as RadioControl;

  }
}

implementation
{
  // sampling frequency in binary milliseconds
  #define SAMPLING_FREQUENCY 16 //24
  #define REPORT_DEST "fec0::100"
  #define MULTICAST "ff02::1"
  //#define SERIAL_FREQUENCY 20
  uint16_t BPM_Avg=0;
  /*Main*/
  volatile uint16_t BPM;                   // used to hold the pulse rate
  volatile uint16_t Signal;                // holds the incoming raw data
  volatile uint16_t IBI = 600;             // holds the time between beats, must be seeded! 
  volatile bool Pulse = FALSE;        // true when pulse wave is high, false when it's low
  volatile bool QS = TRUE;            // becomes true when we find a beat.
   uint16_t BPM_game,BPM_max=0;

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
  volatile bool flag_self= FALSE;                          // flag to check whether calibration is done
  volatile bool flag_other=FALSE;
  volatile bool flag_lost=FALSE;

  struct sockaddr_in6 multicast;
  struct sockaddr_in6 route_dest;
  int N;
  int i=0;
  uint16_t runningTotal=0;

typedef nx_struct statistics{
  //nx_uint16_t thresHold;
  //nx_uint16_t value;
  nx_uint16_t type;
  nx_uint16_t sender;
} stat_statistics;


enum{
  CALIBRATION = 1,
  BEATS = 2,
  THRESHOLD=3,
  LOST=4,
};

  stat_statistics stats,stats_recv,game_send,game_recv;

  event void Boot.booted() {
    
     route_dest.sin6_port = htons(7000);
     inet_pton6(MULTICAST, &route_dest.sin6_addr);
     call multicastUdp.bind(7000);

     multicast.sin6_port = htons(4000);
     inet_pton6(MULTICAST, &multicast.sin6_addr);
     call multicastUdp_gameover.bind(4000);

  
    call RadioControl.start();
    //call calib.stop();
    call calib.startOneShot(3000);
    call Timer.startPeriodic(SAMPLING_FREQUENCY);
    //call Leds.led0On();

  }

  event void RadioControl.stopDone(error_t e){}
  event void RadioControl.startDone(error_t e){}
  

  event void calib.fired(){
    char *reply_buf = call ReadCmd.getBuffer(50);
    int len ;
    BPM_game=BPM;
    if (BPM_game<=60)
    {
    
     call Leds.led0On();
     call Leds.led2Off();
    
   
    
    len=sprintf(reply_buf,"Beats per minute :%d \n",BPM);
    call ReadCmd.write(reply_buf,len);
     
    call calib.startOneShot(3000);
    }
    else
    {

          call Leds.led0Off();
          call Leds.led2On();
          call calib_5s.startOneShot(8000);
          call calib_1s.startPeriodic(1000);
    }

    //call Leds.led2On();
    // call calib.stop();
   
  
}


event void calib_1s.fired()
{
 char *reply_buf = call ReadCmd.getBuffer(50);
 int len ;
 BPM_Avg+=BPM;
 len= sprintf(reply_buf,"BPM taking average: %d:\n",BPM_Avg);
 call ReadCmd.write(reply_buf,len);

}
event void calib_5s.fired()
{
 char *reply_buf = call ReadCmd.getBuffer(50);
    int len ;
call calib_1s.stop();
BPM_Avg=BPM_Avg/7;
len= sprintf(reply_buf,"BPM Avg: %d:\n",BPM_Avg);
call ReadCmd.write(reply_buf,len);
if(BPM_Avg>=85)
{
  stats.type=CALIBRATION;
  stats.sender=TOS_NODE_ID;
  call multicastUdp.sendto(&route_dest, &stats,sizeof(stats));
  flag_self=TRUE;
  if (flag_other==TRUE)
  { //start game
    len= sprintf(reply_buf,"Starting game\n");
  call ReadCmd.write(reply_buf,len);
  call game_timer.startOneShot(10000);
  call compete_timer.startPeriodic(1000);
}
}
else
{
  len= sprintf(reply_buf,"Calibrating again:\n");
  call ReadCmd.write(reply_buf,len);
  call calib.startOneShot(3000);
}
}
event void multicastUdp_gameover.recvfrom(struct sockaddr_in6 *from, void *data, uint16_t len, struct ip6_metadata *meta)
{
  int leng ;
  char *reply_buf = call ReadCmd.getBuffer(50);
  memcpy(&stats_recv, data, sizeof(stats_recv));
  if(stats_recv.type==LOST)
  {
   flag_lost=TRUE;
  }
}
 event void multicastUdp.recvfrom(struct sockaddr_in6 *from, void *data, uint16_t len, struct ip6_metadata *meta)
{
  int leng ;
  char *reply_buf = call ReadCmd.getBuffer(50);
  memcpy(&stats_recv, data, sizeof(stats_recv));
  if(stats_recv.type==CALIBRATION)
  flag_other=TRUE; 
 if(flag_self==TRUE)
 {
  leng= sprintf(reply_buf,"Starting game\n");
  call ReadCmd.write(reply_buf,leng); // start game here
  call game_timer.startOneShot(10000);
  call compete_timer.startPeriodic(1000);
  //call Leds.led0On();
}
/*else if(stats_recv.type==LOST)
{
  flag_lost=TRUE;
  leng= sprintf(reply_buf,"I won\n");
  call game_timer.stop();
  call compete_timer.stop();
  call ReadCmd.write(reply_buf,leng);
}
else 
;*/
}
event void game_timer.fired()
{
 char *reply_buf = call ReadCmd.getBuffer(50);
int len ;
call compete_timer.stop();
len=sprintf(reply_buf,"Tie game\n");
call ReadCmd.write(reply_buf,len);
}
event void compete_timer.fired()
{char *reply_buf = call ReadCmd.getBuffer(50);
int len ;
 len= sprintf(reply_buf,"My BPM is: %d \n",BPM);
 call ReadCmd.write(reply_buf,len);
 
 if (flag_lost==TRUE)
  {
    call compete_timer.stop();
    call game_timer.stop();
    len= sprintf(reply_buf,"I Won in if cond\n");
  call ReadCmd.write(reply_buf,len);
  }
  else if ((BPM>BPM_Avg+10)||(BPM<BPM_Avg-10))
  {
  len= sprintf(reply_buf,"I lost in game_timer\n");
  call ReadCmd.write(reply_buf,len);
  call game_timer.stop();
  call compete_timer.stop();
  stats.type=LOST;
  stats.sender=TOS_NODE_ID;
  //flag_lost=TRUE;
  call multicastUdp_gameover.sendto(&route_dest, &stats,sizeof(stats));
  //multicast  
  }

}
  event void Timer.fired() 
  {
    call Read.read();
  }

  event void Read.readDone(error_t result, uint16_t data) 
  {    
      printf("%d\n",data );
                                            //no interrupt while doing this part 
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
   event char* ReadCmd.eval(int argc, char** argv) {
    char *reply_buf = call ReadCmd.getBuffer(50);
    int len ;
    len=sprintf(reply_buf,"Beats per minute :%d \n",BPM);
    return reply_buf;
  }
  //event void game.fired() {}
  


  

  event char* SyncCmd.eval(int argc, char** argv)
    {
      char *reply_buf= call SyncCmd.getBuffer(50);
      int len; 
      len=sprintf(reply_buf,"Starting Game\n");
      //call Leds.led0Off();
      //flag=TRUE;
      //call game.startOneShot(10000);
      return reply_buf;
    }
    event char* StopCmd.eval(int argc, char* argv[]) 
    {
    char* reply_buf = call StopCmd.getBuffer(35);
    int len;
    len= sprintf(reply_buf,"Stoping Run\n");
    //call Leds.led0On();
    //flag=FALSE;
    return reply_buf;
    }
   /* event  char* StartGame(int argc,char* argv)
    {
      char* reply_buf = call StopCmd.getBuffer(35);
      int len=0;
      

    }*/
}
