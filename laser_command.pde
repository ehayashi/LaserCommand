//
// Laser Command
// This is a game which uses a laser pointer and a 8x8 matrix LED
// as an two-dimensional input device.
// For more details, see
// http://www.cs.cmu.edu/~ehayashi/projects/lasercommand/
//
//   Developed Eiji Hayashi  
//   2010/03/26 Version 1.0
// 
// *** Wiring ***
// This code assumes:
//   D2 to D9 are connected to cathodes 
//   A0 to A7 are connected to anodes
//   D11 and D12 are connected to A6 and A7 respectively
//   D10 is connected to a piezo
// Please refer to circuit diagrams for more details.
//

#ifndef cbi
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#endif
#ifndef sbi
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
#endif

#include <avr/delay.h>
#include <Tone.h>

Tone toneLib;

const int title[8][8] = { // Laser Command
    { 0x00, 0x40, 0x40, 0x43, 0x42, 0x42, 0x7B, 0x00},
    { 0x00, 0x00, 0x1D, 0x91, 0x9D, 0x85, 0xDD, 0x00},
    { 0x00, 0x00, 0xD2, 0x54, 0xD8, 0x10, 0xD0, 0x00},
    { 0x00, 0x3C, 0x20, 0x21, 0x21, 0x21, 0x3D, 0x00},
    { 0x00, 0x00, 0x00, 0xDF, 0x55, 0x55, 0xD5, 0x00},      
    { 0x00, 0x00, 0x00, 0x7D, 0x55, 0x55, 0x55, 0x00},      
    { 0x00, 0x00, 0x00, 0xCE, 0x4A, 0x4A, 0xEA, 0x00},
    { 0x00, 0x20, 0x20, 0xE0, 0xA0, 0xA0, 0xE0, 0x00}
  };
      
const unsigned char score_charset[10][8] = {
    {0x0,0x0,0x7,0x5,0x5,0x5,0x7,0x0},    //0
    {0x0,0x0,0x2,0x2,0x2,0x2,0x2,0x0},    //1
    {0x0,0x0,0x7,0x1,0x7,0x4,0x7,0x0},    //2
    {0x0,0x0,0x7,0x1,0x7,0x1,0x7,0x0},    //3
    {0x0,0x0,0x5,0x5,0x7,0x1,0x1,0x0},    //4
    {0x0,0x0,0x7,0x4,0x7,0x1,0x7,0x0},    //5
    {0x0,0x0,0x7,0x4,0x7,0x5,0x7,0x0},    //6
    {0x0,0x0,0x7,0x1,0x1,0x1,0x1,0x0},    //7
    {0x0,0x0,0x7,0x5,0x7,0x5,0x7,0x0},    //8
    {0x0,0x0,0x7,0x5,0x7,0x1,0x1,0x0}     //9
  };
 
int thresh[8];        // threshold values used in chechColumn
int counter = 0;      // a counter incremented in loop()
int gameCounter = 0;  // a counter incremented in game()
int gameSpeed = 10;   // game speed
int gameInterval = 1; // frequency at which an enemy is added
int score = 0;        // game score
int miss = 0;         // number of misses

enum Status { titleScreen,
                    gameScreen,
                    countDownScreen,
                    gameoverScreen,
                    scoreScreen,
                    sensorDemoScreen };
Status gameStatus;

// this variable stores contents shown in a matrix LED
int screen[3][10] = {{0,0,0,0,0,0,0,0,0,0},
                    {0,0,0,0,0,0,0,0,0,0},
                    {0,0,0,0,0,0,0,0,0,0}};

void setup(){
  //Serial.begin(9600);
  randomSeed( analogRead(0) );
  toneLib.begin(10);
  DDRC = B11111111;
  DDRD = B11111111;
  PORTD = B11111111;

  // set prescale to 16
  sbi(ADCSRA,ADPS2) ;
  cbi(ADCSRA,ADPS1) ;
  cbi(ADCSRA,ADPS0) ;

  initialize();
  // adjust threshold
  adjustThreshCol();
}

// main loop
void loop()
{
  int row = checkRow();  
  int col = checkColumn();
  
  if( row != 8 && col != 8 && gameStatus != sensorDemoScreen )
    hitDetection( row, col );
   /* 
  Serial.print(row);
  Serial.print(",");
  Serial.println(col);
  */
  setDisplayMode();
  if( counter % gameSpeed == 0){
    switch( gameStatus ){
      case titleScreen:
        gameSpeed = 4;
        showTitle();
        break;
      case countDownScreen:
        gameSpeed = 10;
        showCountDown();
        gameStatus = gameScreen;
        gameCounter = 0;
        break;
      case gameScreen:
        game();
        break;
      case gameoverScreen:
        showGameOver();
        gameStatus = scoreScreen;
        break;
      case scoreScreen:
        showScore();
        initialize();
        gameStatus = titleScreen;
        break;
      case sensorDemoScreen:
        showSensorDemo( row, col );
        break;
      default:
        break;
    }
  }

  // Display

  for( int i=0; i<5; i++ ){
    for( int row=0; row<8; row++ ){
      
      if( row<6 ){
        DDRD |= 1 << (row+2);
      }
      else{
        DDRB |= 1 << (row-6);
      }
   
      PORTC = screen[0][row+2] & B00111111;
      PORTB = ( screen[0][row+2] & B11000000 ) >> 3;
      _delay_us( 300 );
      PORTC = screen[1][row+2] & B00111111;
      PORTB = ( screen[1][row+2] & B11000000 ) >> 3;
      _delay_us( 100 );
      PORTC = screen[2][row+2] & B00111111;
      PORTB = ( screen[2][row+2] & B11000000 ) >> 3;
      _delay_us( 30 );
  
      DDRD &= B00000011;
      DDRB &= B11111100;
     
    }
  }
  
  counter ++;
}

// Check which column is pointed
int checkColumn(){
  int val[8];  // brightness

  // *** clear charges ***
  // make all anodes output and low
  DDRB = B00011000;
  PORTB = B00000000;
  DDRC = B11111111;
  PORTC = B00000000;

  // make all cathodes output and low;
  DDRD |= B11111100;
  DDRB |= B00000011;
  PORTD &= B00000011;
  PORTB &= B11111100;

  _delay_us(10);  // wait for a while to clear charges

  // make all anodes input to measure charges cause by light
  DDRB &= B11100111;
  DDRC = B00000000;
  
  _delay_us(200);  // wiat for a while 
  
  // read analog values at all anodes
  for( int col=0; col<8; col++ ){
    val[col] = analogRead( col );
  }
  
  // calculate difference between current values and thresholds
  for( int col=0; col<8; col++ ){
    val[col] = val[col] - thresh[col];
  }
 
 
  // if the differences are bigger than 10,
  // the column is pointed by a laser pointer
  int signal = 8; 
  for( int col=0; col<8; col++ ){
    if( val[col] > 10 ){
      signal = col;
      break;
    }
  }
  
  // uncomment the following to see sensor values via serial communication
  /* for( int col=0; col<7; col ++ ){
    Serial.print(val[col]);
    Serial.print(",");
  }
  Serial.println(val[7]);
  */
  
  return( signal );
  
}

// Measure analog values at anodes to calculate threshold values.
// Using the threshold values mitigates effects of ambient light conditions
void adjustThreshCol()
{
  for( int cnt=0; cnt<10; cnt ++ ){  // measure the values 100 times and take average
    int val[8];

    // *** clear charges ***
    // make all anodes output and low
    DDRB = B00011000;
    PORTB = B00000000;
    DDRC = B11111111;
    PORTC = B00000000;
  
    // make all cathodes output and low;
    DDRD |= B11111100;
    DDRB |= B00000011;
    PORTD &= B00000011;
    PORTB &= B11111100;
  
    _delay_us(10);  // wait for a while to clear charges
  
    // make all anodes input to measure charges cause by light
    DDRB &= B11100111;
    DDRC = B00000000;

    _delay_us(200);
    int input = 0;
    for( int i=0; i<8; i++ ){
      val[i] = analogRead( i );
      thresh[i] += val[i];
    }
  }  
  
  // take average
  for( int i=0; i<8; i++ ){
    thresh[i] = thresh[i] / 10;
  }  
}

// Check which row is pointed
int checkRow()
{
  int input = 0;
  
  // *** Apply reverse voltage, charge up the pin and led capacitance 
  // make all cathodes high
  DDRD |= B11111100;
  DDRB |= B00000011;
  PORTD |= B11111100;
  PORTB |= B00000011;

  
  // set all anodes low
  DDRC = B00111111;
  PORTC = B11000000;
  DDRB |= B00011000;
  PORTB &= B11100111;

  _delay_us(100);  // wait for a while to charge
  
  // Isolate the pin connected to cathods
  DDRD &= B00000011;  // make N0-N5 INPUT
  DDRB &= B11111100;  // make N6 and N7 INPUT
  
  // turn off internal pull-up resistor
  PORTD &= B00000011; // make N0-N5 LOW
  PORTB &= B11111100; // make N6 and N7 LOW  

  // measure how long it takes for cathodes to become low
  int val[8] = {100,100,100,100,100,100,100,100};
  for( int cnt=0; cnt<50; cnt++ ){
    for( int r=0; r<8; r++ ){
      if( digitalRead( 2+r ) == LOW && val[r] == 100 )
        val[r] = cnt;
    }
  }
  
  // uncomment the following if you want to check values
  /*
  for( int r=0; r<7; r++ ){
    Serial.print( val[r] );
    Serial.print(",");
  }
  Serial.println( val[7] );
*/
  // if a pin becomes low quicker than 50, the pin is pointed
  int signal = 8;
  for( int i=0; i<8; i++ ){
    if( val[i] < 49 ){
      signal = i;
      break;
    }
  }

  return( signal );
}

void game()
{
  // bottom detection
  if( screen[0][9] != 0 ){  //something reaches to bottom
    miss ++;
    toneLib.play(NOTE_C2);
    delay(50);
    toneLib.stop();

    if( miss == 3 ){
      gameStatus = gameoverScreen;
      for( int i=0; i<3; i++ ){
        for( int j=0; j<10; j++ ){
          screen[i][j] = 0;
        }
      }
      return;
    }
    int mask = ~screen[0][9];
    for( int i=0; i<3; i++ ){  // clear a missile
      for( int j=7; j<10; j++ ){
        screen[i][j] &= mask;
      }
    }
    
    // flash
    int data[8] = {255,255,255,255,255,255,255,255};
    for( int i=0; i<5; i++ )
      showDisplay( data );
  }
    
  
  // scroll
  for( int i=0; i<9; i++ ){
    screen[0][9-i] = screen[0][8-i];
    screen[1][9-i] = screen[1][8-i];
    screen[2][9-i] = screen[2][8-i];
  }
  screen[0][0] = 0;
  screen[1][0] = 0;
  screen[2][0] = 0;
  
  // add a missile
  if( gameInterval == gameCounter ){
    gameInterval = gameCounter + random(3, 10);
    int pos = random( 7 );
      screen[0][2] = 1 << pos;
      screen[1][2] = screen[0][2];
      screen[2][2] = screen[0][2];
      screen[1][1] = screen[0][2];
      screen[2][1] = screen[0][2];
      screen[2][0] = screen[0][2];
  }
  
  
  gameCounter ++;
}

void hitDetection(int row, int col)
{
  if( gameStatus == titleScreen ){
    if( row != 7 ){
      gameStatus = countDownScreen;
    }
    else{
      gameStatus = sensorDemoScreen;
      counter = 0;
    }
    for( int i=0; i<3; i++ ){
      for( int j=0; j<10; j++ ){
        screen[i][j] = 0;
      }
    }
  }
  
  int mask, clear_mask;
  mask = 1 << col;
  clear_mask = 1 << col;
  clear_mask = ~clear_mask;
 
  int start, end;  // clear area
  int hit = 0;
  start = max( row-1, 0 );
  end = min( row+5, 9 );
  
  for( int r=start; r<=end; r++ ){
    if( (screen[2][r] & mask) != 0 ){
      hit = 1;
      toneLib.play( NOTE_C7 );
      delay(10);
      toneLib.stop();
      for( int i=0; i<3; i++ ){
        screen[i][r] = screen[i][r] & clear_mask;
      }
    }
  }
  
  score += hit;

  if( ( score % 4 == 0 ) && hit == 1 )
    gameSpeed = max( gameSpeed - 1, 1 );
}

void showCountDown()
{
  int count[3][8] = 
           {{B00000000,
             B00111100,
             B00000100,
             B00111100,
             B00000100,
             B00000100,
             B00111100,
             B00000000},

             
            {B00000000,
             B00111100,
             B00000100,
             B00111100,
             B00100000,
             B00100000,
             B00111100,
             B00000000},

            {B00000000,
             B00011000,
             B00011000,
             B00011000,
             B00011000,
             B00011000,
             B00011000,
             B00000000}};             
  int go[8] = {B00000000,
               B11110000,
               B10010000,
               B10000111,
               B10110101,
               B10010101,
               B11110111,
               B00000000};

  
  //play sound
  toneLib.play( NOTE_B4 );
  delay( 100 );
  toneLib.play( NOTE_E5 );
  delay( 200 );
  toneLib.stop();
  
  
  DDRC |= B00111111;  // make P0 to P5 port output
  DDRB |= B00011000;   // make P6 and P7 output
  DDRD &= B00000011;  // make N0 to N5 input
  DDRB &= B11111100;  // make N6 and N7 input
  PORTD &= B00000011;
  PORTB &= B11111100;

  int data[8];
  int line[3][8];

  int i;
  for( int c=0; c<36; c++ ){
    if( c < 12 ){
      for( i=0; i<8; i++ ){
        data[i] = count[0][i];
      }
      for( i=0; i<c; i++ ){
        data[i] = count[1][i];
      }
    }
    else if( c < 24 ){
      for( i=0; i<8; i++ ){
        data[i] = count[1][i];
      }
      for( i=0; i<c-12; i++ ){
        data[i] = count[2][i];
      }
    }
    else{
      for( i=0; i<8; i++ ){
        data[i] = count[2][i];
      }
      for( i=0; i<c-24; i++ ){
        data[i] = 0;
      }
    }
    
    for( int j=0; j<3; j++ ){
    for( i=0; i<8; i++ ){
      line[j][i] = data[i];
    }
    }
    if( c % 12 < 9 && c % 12 > 0 ){
      line[2][(c%12-1)] = B11111111;
      line[1][(c%12-1)] = B11111111;
      line[0][(c%12-1)] = B11111111;
    }
    if( c % 12 < 10 && c % 12 > 1 ){
      line[2][(c%12-2)] = B11111111;
      line[1][(c%12-2)] = B11111111;
    }
    if( c % 12 < 11 && c % 12 > 2 ){
      line[2][(c%12-3)] = B11111111;
    }
    
    for( int i=0; i<5; i++ ){
      showDisplay3( line );
    }
  }
  
  for( int i=0; i<40; i++ ){
    showDisplay( go );
  }
  delay(320);
  for( int i=0; i<100; i++ ){
    showDisplay( go );
  }
}

void setDisplayMode()
{
  DDRC |= B00111111;  // make P0 to P5 port output
  DDRB |= B00011000;   // make P6 and P7 output
  DDRD &= B00000011;  // make N0 to N5 input
  DDRB &= B11111100;  // make N6 and N7 input
  PORTD &= B00000011;
  PORTB &= B11111100; 
}

void showGameOver()
{ 
  int gameOver[8] = {0,0,0,0,0,0,0,0};
  
  for( int i=0; i<8; i++ ){
    gameOver[7-i] = B11111111;
    for( int j=0; j<10; j++ ){
      showDisplay( gameOver );
    }
  }
  
  for( int i=0; i<8; i ++ ){
    if( i%2 == 0 ){
      for( int j=0; j<100; j++ ){
        showDisplay( gameOver );
      }
    }
    else{
      delay(100);
    }
  }
}

void showScore()
{
  int row = 7;
  int col = 0;
  int data[8] = {0,0,0,0,0,0,0,0};
  
  for( int i=0; i<score; i++ ){
    int lower = i%10;
    int higher = (int)(i/10);
    
    toneLib.play( NOTE_C6 );
    delay(10);
    toneLib.stop();

    for( int j=0; j<8; j++ ){
      data[j] = score_charset[higher][j]<<4 | score_charset[lower][j];
    }
    for( int j=0; j<max((i+10-score)*10,1); j ++ )
      showDisplay( data );
  }
  
  for( int i=0; i<500; i++ ){
    showDisplay(data);
  }
}

void showTitle()
{
  int titleLength = 8;
  int data[8] = {0,0,0,0,0,0,0,0};
  
  int i = (int)(gameCounter/8);
  int c = gameCounter % 8; 
  
  for( int r=0; r<8; r++ ){
    if( i>0 ){
      screen[0][r+2] = title[i-1][r] << (c);
      screen[1][r+2] = title[i-1][r] << (c);
      screen[2][r+2] = title[i-1][r] << (c);
    }
    else{
      screen[0][r+2] = 0;
      screen[1][r+2] = 0;
      screen[2][r+2] = 0;
    }
    
    if( i < titleLength ){
      screen[0][r+2] |= title[i][r] >> (8-c);
      screen[1][r+2] |= title[i][r] >> (8-c);
      screen[2][r+2] |= title[i][r] >> (8-c);
    }
  }

  gameCounter ++;
  if( gameCounter > titleLength * 8 + 7 ){
    gameCounter = 0;
  }
}


void showDisplay( int data[] )
{
  for( int row=0; row<8; row++ ){
    PORTC = data[row] & B00111111;
    PORTB = ( data[row] & B11000000 ) >> 3;
    
    if( row<6 ){
      DDRD |= 1 << (row+2);
      _delay_us(1000);
      DDRD &= B00000011;
    }
    else{
      DDRB |= 1 << (row-6);
      _delay_us(1000);
      DDRB &= B11111100;
    }
  }
}

void showDisplay3( int data[3][8] )
{
  for( int i=0; i<5; i++ ){
    for( int row=0; row<8; row++ ){
      
      if( row<6 ){
        DDRD |= 1 << (row+2);
      }
      else{
        DDRB |= 1 << (row-6);
      }
   
      PORTC = data[0][row] & B00111111;
      PORTB = ( data[0][row] & B11000000 ) >> 3;
      _delay_us( 300 );
      PORTC = data[1][row] & B00111111;
      PORTB = ( data[1][row] & B11000000 ) >> 3;
      _delay_us( 150 );
      PORTC = data[2][row] & B00111111;
      PORTB = ( data[2][row] & B11000000 ) >> 3;
      _delay_us( 50 );
  
      DDRD &= B00000011;
      DDRB &= B11111100;
     
    }
  }  
}

void initialize()
{
  counter = 0;
  gameCounter = 0;
  gameSpeed = 10;
  gameStatus = titleScreen;
  gameInterval = 1;
  score = 0;
  miss = 0;

  for( int i=0; i<3; i++ ){
    for( int j=0; j<10; j++ ){
      screen[i][j] = 0;
    }
  }
}

void showSensorDemo( int row, int col )
{
  if( counter < 100 )
    return;
   screen[0][row+2] |= 1 << col;
   screen[1][row+2] |= 1 << col;
   screen[2][row+2] |= 1 << col;   
}
