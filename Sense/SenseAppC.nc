

/**
 * 
 * Sensing demo application. See README.txt file in this directory for usage
 * instructions and have a look at tinyos-2.x/doc/html/tutorial/lesson5.html
 * for a general tutorial on sensing in TinyOS.
 * 
 * @author Jan Hauer
 */

configuration SenseAppC 
{ 
} 
implementation { 
  
  components SenseC, MainC, LedsC, new DemoSensorC() as Sensor;

  SenseC.Boot -> MainC;
  SenseC.Leds -> LedsC;
  components new TimerMilliC() as TimerMilliC1; 
  components new TimerMilliC() as TimerMilliC2;
  components new TimerMilliC() as TimerMilliC3; 
  components new TimerMilliC() as TimerMilliC4; 
   components new TimerMilliC() as TimerMilliC5;
   components new TimerMilliC() as TimerMilliC6;

  SenseC.Timer -> TimerMilliC1;
  SenseC.calib -> TimerMilliC2;
  SenseC.calib_5s->TimerMilliC3;
  SenseC.calib_1s->TimerMilliC4;
  SenseC.game_timer->TimerMilliC5;
  SenseC.compete_timer->TimerMilliC6;

  SenseC.Read -> Sensor;

  components IPStackC;
  SenseC.RadioControl -> IPStackC;
  components IPDispatchC;
  components UdpC;
  components UDPShellC;
  components StaticIPAddressTosIdC;
  components RPLRoutingC;
  components new ShellCommandC("read") as ReadCmd;
  SenseC.ReadCmd -> ReadCmd;
  components new ShellCommandC("start") as SyncCmd;
  SenseC.SyncCmd -> SyncCmd;
  components new ShellCommandC("Stop") as StopCmd;
  SenseC.StopCmd -> StopCmd;
  components new UdpSocketC() as multicastUdp;
  SenseC.multicastUdp -> multicastUdp;
  components new UdpSocketC() as multicastUdp_gameover;
  SenseC.multicastUdp_gameover -> multicastUdp_gameover;
  components SerialPrintfC;

}
