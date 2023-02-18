module smallbee1(clk, KEY, SW, L1, L0, led, IRDA_RXD,
VGA_HS, VGA_VS ,VGA_R, VGA_G, VGA_B, VGA_BLANK_N, VGA_CLOCK, VGA_SYNC_N);
//****************************************************************************
//**********************************I/O pins**********************************
//****************************************************************************
input             clk;                               //system clock 50MHz
input      [3:0]  KEY;                               //raw button
input      [7:0]  SW;                                //raw switch
input             IRDA_RXD;                          //infrared  data
wire              ready;                             //IR_data is ready
wire       [31:0] IR_data;                           //from remote control
wire              rst;                               //reset by KEY[0] (debounced)
output reg [6:0]  led;                               //diode 
output     [6:0]  L1, L0;                            //7 segments LED
output reg          VGA_HS, VGA_VS;                    //Hsync, Vsync
output reg [7:0]  VGA_R, VGA_G, VGA_B;               //color information
output            VGA_BLANK_N, VGA_CLOCK;            //VGA pins
output            VGA_SYNC_N = 1'b0;                 //not used
//****************************************************************************
//*********************************Variables**********************************
//****************************************************************************
reg [10:0] counterHS;                                //for Hsync
reg [9:0]  counterVS;                                //for Vsync
reg        clk25M;                                   //VGA spec frequency
reg [9:0]  X, Y;                                     //pixel coordinate
reg [2:0]  ns,cs;                                    //next state, current state
wire       reset_state;                              //logic cs==0
reg        lose, win;                                //changing state signal
reg [4:0]  numofdis;                                 //number of disapeared monster (30 atmost)
reg [1:0]  sum_cnt;                                  //for  delay 4s after a game
reg        sum_done;                                 //sum_cnt done 
reg [24:0] cnt_1Hz;                                  //for clk_1Hz
reg        clk_1Hz;                                  //for sum_cnt
reg [3:0]  numoftouch;                               //number of monsters touching baseline
reg [29:0] mon_touch;                                //which one is touching
reg [1:0]  heart;                                    //for three lifes
wire       en_loss;                                  //for subtracting heart
wire[1:0]  new_heart;                                //remainding hearts after subtraction
reg [2:0]  tough;                                    //toughness 0~7
wire       start, start_bar;                         //start signal
assign     start = !start_bar;
wire       move_l, move_r, move_l_bar, move_r_bar;   //from left right button
assign     move_l = !move_l_bar;
assign     move_r = !move_r_bar;
wire       en_obj_move;                              //enable object tank to move                   
wire[3:0]  move_speed;                               //control by SW[7:4]
wire[3:0]  fire;                                     //control by SW[3:0]
reg [9:0]  objXmon [29:0];                           //coordinate of monsters
reg [9:0]  objYmon [29:0];
reg [9:0]  objXbul [19:0];                           //coordinate of bullets
reg [9:0]  objYbul [19:0];
reg [9:0]  objX;                                     //coordinate of tank
reg [9:0]  objY = 10'd447;                           //fixed
reg [24:0] cnt_mon, cnt_mon_max;                     //counter for mon_move(monster move)
wire       en_cnt_mon;                               //enable signal
reg [3:0]  mon_move_cnt;
reg [1:0]  mon_move;                                 //types of move in EPI1: stay, left, right, down
reg [18:0] cnt_mon2, cnt_mon2_max;                   //counter for mon_move(EPI2)
reg [1:0]  mon_move2 [9:0];                          //types of move in EPI2: up left, down left, down right, up right
reg [9:0]  touch_up, touch_left;                     //monsters' touch state in EPI2 
reg [9:0]  touch_down, touch_right;
reg [9:0]  virtual_line;                             //limit the downward speed of monster in EPI2
reg [29:0] strike;                                   //which monter being striked
reg [19:0] hit;                                      //which bullet hits monster
reg [16:0] cnt_bul;                                  //counter for bullet for 420pixels/s
reg [19:0] whichbul;                                 //which bullet is allowed to be lauched
reg [19:0] bul_used;                                 //which bullet is used since allowed
reg [24:0] cnt_075s;                                 //counter for shooting frequency
wire       en_cnt_075s;                              //and its enable signal
reg        clk_075s;                                 //and clock
reg [19:0] bul_mod;                                  //mode of bullets: stand by, go up
reg [18:0] cnt_obj;                                  //counter for tank for 160pixels/s
reg [18:0] cnt_obj_max;                              //depend on move_speed
reg [29:0] in_mon;                                   //scanning pixel is in monsters
reg [19:0] in_bul;                                   //scanning pixel is in bullets
reg        in_obj, in_mid;                           //scanning pixel is in tank, middle(for text displaying)
reg [23:0] heart_color, mon_color, obj_color;        //color of 3 objects
wire[5:0] relaX_heart, relaY_heart;                  //relative coordinate for heart color acquire
wire[9:0] sub_heart;                                 //for calculating that coordinate(no need for y)
wire[9:0] x_heart, y_heart;                          //real x,y of the image
wire[9:0] addr_heart;                                //combine x_heart and y_heart
reg [23:0] heart_color3, heart_color2, heart_color1; //3 states of heart, so 3 color
reg [23:0] heart3 [0:767];                           //images memory
reg [23:0] heart2 [0:767];
reg [23:0] heart1 [0:767];
reg [23:0] mon_img [0:1023];
reg [23:0] obj_img [0:1023];
wire[4:0] relaX_mon, relaY_mon, relaX_obj, relaY_obj;//same as rela_heart but with monster and object tank 
reg [9:0] sub_mon0, sub_mon1;                        //coordinate of which  monter being displaying 
wire[9:0] sub_mon2, sub_mon3, sub_obj0, sub_obj1;    //for calculating coordinates
wire[9:0] x_mon, y_mon, x_obj, y_obj;                //real x,y of the images
wire[9:0] addr_mon, addr_obj;                        //combine x,y for address
reg [23:0] start_color, win_color, lose_color;       //color of text images
reg [23:0] start_img [0:16383];                      //text images memory
reg [23:0] win_img [0:16383];
reg [23:0] lose_img [0:16383];
wire[9:0]  midx = 10'd256;                           //middle of screen
wire[9:0]  midy = 10'd176;
reg [6:0]  relaX_start, relaY_start;                 //same as rela_heart but with text
reg [9:0]  sub_start0, sub_start1;                   //for calculating coordinates
reg [13:0] x_start, y_start, addr_start;             //real x,y and combine for address
reg [7:0]  score;                                    //current score
reg [3:0]  score_gain;                               //score gained at the moment
wire [3:0] c,d;                                      //decimal score for displaying
integer i0,i1;
parameter IDLE=3'd0,EPI1=3'd1,EPI2=3'd2,LOSE=3'd3,WINN=3'd4;
//****************************************************************************
//***************************Call functions needed****************************
//****************************************************************************
debounce deb0 (clk,{SW,KEY},{move_speed,fire,move_l_bar,move_r_bar,start_bar,rst});
bin2bcd enc3 (score,c,d);
encode enc1 (c,L1);
encode enc2 (d,L0);
IR_RECEIVE U1(clk,rst,IRDA_RXD,ready,IR_data);
//****************************************************************************
//************************************VGA*************************************
//****************************************************************************
parameter H_FRONT  = 10'd16; //spec parameters
parameter H_SYNC   = 10'd96;
parameter H_BACK   = 10'd48;
parameter H_ACT    = 10'd640;
parameter H_BLANK  = H_FRONT + H_SYNC + H_BACK;
parameter H_TOTAL  = H_FRONT + H_SYNC + H_BACK + H_ACT;
parameter V_FRONT  = 10'd11;
parameter V_SYNC   = 10'd2;
parameter V_BACK   = 10'd32;
parameter V_ACT    = 10'd480;//
parameter V_BLANK  = V_FRONT + V_SYNC + V_BACK;
parameter V_TOTAL  = V_FRONT + V_SYNC + V_BACK + V_ACT;
assign VGA_BLANK_N = !((counterHS<H_BLANK)||(counterVS<V_BLANK));
assign VGA_CLOCK   = !clk25M; //VGA works at negedge
always@(posedge clk) begin
   if(!rst)   clk25M <= 1'b0;
   else       clk25M <= !clk25M;
end
always@(posedge clk25M) begin //for Hsync
   if(!rst) begin
      counterHS <= 11'd0;
      VGA_HS    <= 1'b0;
      X         <= 10'd0;
   end else begin
      if(counterHS == H_TOTAL)
         counterHS <= 11'd0;
      else
         counterHS <= counterHS + 1'b1;
      if(counterHS == H_FRONT-1'd1)
         VGA_HS <= 1'b0;
      else if(counterHS == H_FRONT + H_SYNC -1'd1)
         VGA_HS <= 1'b1;
      else 
         VGA_HS <= VGA_HS;
      if(counterHS >= H_BLANK)
         X <= counterHS-H_BLANK; //X = 0~639
      else
         X <= 10'd0;
   end
end
always@(posedge clk25M) begin //for Vsync
   if(!rst) begin
      counterVS <= 10'd0;
      VGA_VS    <= 1'b0;
      Y         <= 10'd0;
   end else begin
      if(counterVS == V_TOTAL)
         counterVS <= 10'd0;
      else if(counterHS == H_TOTAL)
         counterVS <= counterVS + 1'b1;
      else
         counterVS <= counterVS;
      if(counterVS == V_FRONT-1'd1)
         VGA_VS <= 1'b0;
      else if(counterVS == V_FRONT + V_SYNC -1'd1)
         VGA_VS <= 1'b1;
      else
         VGA_VS <= VGA_VS;
      if(counterVS >= V_BLANK)
         Y <= counterVS-V_BLANK; //Y = 0~479
      else
         Y <= 10'd0;
   end
end
//****************************************************************************
//*******************************PREPROCESSING********************************
//****************************************************************************
always@(*)begin //next state logic
   case(cs)
   IDLE: ns = (start)?    EPI1 : IDLE; //start button pressed
   EPI1: ns = (win)?      EPI2 : (lose)? LOSE : EPI1;
   EPI2: ns = (win)?      WINN : (lose)? LOSE : EPI2;
   LOSE: ns = (sum_done)? IDLE : LOSE; //stand by for 4 seconds
   WINN: ns = (sum_done)? IDLE : WINN;
   default: ns = IDLE;
   endcase
end
always@(posedge clk)begin //state transfer
   if(!rst) cs <= IDLE;
   else     cs <= ns;
end
always@(negedge clk)begin //setting toughness by remote control
   if(!rst)
      tough <= 3'd0;
   else if((!ready) && (IR_data[23:19]==5'd0))
      tough <= IR_data[18:16]; //ignore non 0~7 keys
   else
      tough <= tough;
end
always@(*)begin //display toughness through leds
   case(tough)
   3'd0: led <= 7'b0;
   3'd1: led <= 7'b1;
   3'd2: led <= 7'b11;
   3'd3: led <= 7'b111;
   3'd4: led <= 7'b1111;
   3'd5: led <= 7'b11111;
   3'd6: led <= 7'b111111;
   default: led <= 7'b1111111;
   endcase
end
always@(posedge clk)begin //scoring
   if(!rst) score <= 8'd0;
   else begin
      case(cs)
      IDLE: score <= 8'd0;
      EPI1: score <= numofdis+heart-2'd3;     //+1 for killing a monster and -1 for lossing heart
      EPI2: score <= score+{score_gain,1'b0}; //doubled for higher score in EPIC2
      default: score <= score;
      endcase
   end
end
always@(*)begin //score gain in EPI2
   score_gain = 4'd0;
   for(i0=8;i0>=0;i0=i0-1)begin
      score_gain = score_gain+strike[i0]; //based on number of currently striked monsters
   end
end
always@(*)begin              //win-lose conditions
   win  = (numofdis==5'd30); //all monster disapear
   lose = (heart==2'd0);     //no more heart
end
assign reset_state = (cs==IDLE);
always@(*)begin
   numofdis   = 5'd0; //number of disapeared monsters
   numoftouch = 4'd0; //number of monsters touching baseline(10 at most)
   for(i0=29;i0>=0;i0=i0-1)begin
      numofdis   = numofdis+(objYmon[i0]==10'd0);
      numoftouch = numoftouch+mon_touch[i0];
   end
end
always@(*)begin
   for(i0=29;i0>=0;i0=i0-1)begin
      mon_touch[i0]=(objYmon[i0]>=10'd415); //baseline at 479-32=447, monster height is 32
   end
end
assign en_loss   = numoftouch<={2'd0,heart}; //enough hearts to be loss
assign new_heart = heart - numoftouch[1:0];  //after substracting numoftouch
always@(posedge clk)begin //calculating hearts
   if(!rst)begin
      heart <= 2'd3;
   end
   else begin
      case(cs)
      EPI1,EPI2: begin
         if(numoftouch>4'd0)
            heart <= (en_loss)? new_heart : 2'd0;
         else
            heart <= heart;
      end
      default: heart <= 2'd3;
      endcase
   end
end
//****************************************************************************
//**********************************MONSTER***********************************
//****************************************************************************
always@(*)begin
   strike = 30'd0;
   hit    = 20'b0;
   for(i0=29;i0>=0;i0=i0-1)begin
      for(i1=19;i1>=0;i1=i1-1)begin
         if((objYmon[i0]>=objYbul[i1]-10'd31) &&
            (objYmon[i0]<=objYbul[i1])          && 
            (objXmon[i0]>=objXbul[i1]-10'd31) && 
            (objXmon[i0]<=objXbul[i1]+10'd4)) begin
            strike[i0] = 1'b1; //whether a monster is striked by bulllet
            hit   [i1] = 1'b1; //whether a bullet is hiting a monster
         end
      end
   end
end
assign en_cnt_mon = cnt_mon>=cnt_mon_max; //default is clk_2Hz
always@(posedge clk)begin //how all monster move in EPI1
   if(!rst)            mon_move_cnt <= 4'd0;
   else if(en_cnt_mon) mon_move_cnt <= (mon_move_cnt==4'd9)? 4'd0 : mon_move_cnt+1'b1;
   else if(cs==EPI1)   mon_move_cnt <= mon_move_cnt;
   else                mon_move_cnt <= 4'd0;
end
always@(posedge clk)begin //repeat LLRRD RRLLD
   if(!rst)                mon_move <= 2'd0;
   else if(en_cnt_mon)begin
      case(mon_move_cnt)
      4'd0,4'd1,4'd7,4'd8: mon_move <= 2'd1; //move left
      4'd2,4'd3,4'd5,4'd6: mon_move <= 2'd2; //move right
      default:             mon_move <= 2'd3; //move down
      endcase
   end
   else                    mon_move <= 2'd0; //hold
end
always@(posedge clk)begin                                 //virtual line in EPI2
   if(!rst)            virtual_line <= 10'd180;           //upper part of the screen
   else if(en_cnt_mon) virtual_line <= virtual_line+1'b1; //go down after a while
   else if(cs==EPI2)   virtual_line <= virtual_line;
   else                virtual_line <= 10'd180;
end
always@(*)begin //touching state of monsters in EPI2
   for(i0=9;i0>=0;i0=i0-1)begin
      touch_up[i0]   = (objYmon[i0]<=10'd31);
      touch_left[i0] = (objXmon[i0]<=10'd1);
      touch_down[i0] = (objYmon[i0]>=virtual_line);
      touch_right[i0]= (objXmon[i0]>=10'd608); //639-31
   end
end  
always@(posedge clk)begin   //how all monster move in EPI2
   if(!rst)begin            //move ramdomly (visually)
      mon_move2[9] <= 2'd0; //up left
      mon_move2[8] <= 2'd1; //down left
      mon_move2[7] <= 2'd2; //down right
      mon_move2[6] <= 2'd3; //up right
      mon_move2[5] <= 2'd0;
      mon_move2[4] <= 2'd1;
      mon_move2[3] <= 2'd2;
      mon_move2[2] <= 2'd3;
      mon_move2[1] <= 2'd0;
      mon_move2[0] <= 2'd1;
   end
   else if(cs==EPI2) begin
      for(i0=9;i0>=0;i0=i0-1)begin //remain moving direction or rebound when hiting the edges
            case(mon_move2[i0])
            2'd0: if(touch_up[i0])         mon_move2[i0] <= 2'd1;
                  else if(touch_left[i0])  mon_move2[i0] <= 2'd3;
                  else                     mon_move2[i0] <= mon_move2[i0];
            2'd1: if(touch_left[i0])       mon_move2[i0] <= 2'd2;
                  else if(touch_down[i0])  mon_move2[i0] <= 2'd0;
                  else                     mon_move2[i0] <= mon_move2[i0];
            2'd2: if(touch_down[i0])       mon_move2[i0] <= 2'd3;
                  else if(touch_right[i0]) mon_move2[i0] <= 2'd1;
                  else                     mon_move2[i0] <= mon_move2[i0];
            2'd3: if(touch_right[i0])      mon_move2[i0] <= 2'd0;
                  else if(touch_up[i0])    mon_move2[i0] <= 2'd2;
                  else                     mon_move2[i0] <= mon_move2[i0];
            endcase
      end
   end
   else begin //initialize
      mon_move2[9] <= 2'd0;
      mon_move2[8] <= 2'd1;
      mon_move2[7] <= 2'd2;
      mon_move2[6] <= 2'd3;
      mon_move2[5] <= 2'd0;
      mon_move2[4] <= 2'd1;
      mon_move2[3] <= 2'd2;
      mon_move2[2] <= 2'd3;
      mon_move2[1] <= 2'd0;
      mon_move2[0] <= 2'd1;
   end
end
always@(posedge clk)begin //x,y coordinate of monsters
   if(!rst)begin
      for(i0=29;i0>=0;i0=i0-1)begin
         {objXmon[i0],objYmon[i0]} <= 20'd0;
      end
   end
   else begin
      case(ns)
      EPI1: begin
         if(reset_state)begin //initial position
            {objXmon[29],objYmon[29]} <= {10'd87,10'd32};
            {objXmon[28],objYmon[28]} <= {10'd135,10'd32};
            {objXmon[27],objYmon[27]} <= {10'd183,10'd32};
            {objXmon[26],objYmon[26]} <= {10'd231,10'd32};
            {objXmon[25],objYmon[25]} <= {10'd279,10'd32};
            {objXmon[24],objYmon[24]} <= {10'd327,10'd32};
            {objXmon[23],objYmon[23]} <= {10'd375,10'd32};
            {objXmon[22],objYmon[22]} <= {10'd423,10'd32};
            {objXmon[21],objYmon[21]} <= {10'd471,10'd32};
            {objXmon[20],objYmon[20]} <= {10'd519,10'd32};
            {objXmon[19],objYmon[19]} <= {10'd87,10'd72};
            {objXmon[18],objYmon[18]} <= {10'd135,10'd72};
            {objXmon[17],objYmon[17]} <= {10'd183,10'd72};
            {objXmon[16],objYmon[16]} <= {10'd231,10'd72};
            {objXmon[15],objYmon[15]} <= {10'd279,10'd72};
            {objXmon[14],objYmon[14]} <= {10'd327,10'd72};
            {objXmon[13],objYmon[13]} <= {10'd375,10'd72};
            {objXmon[12],objYmon[12]} <= {10'd423,10'd72};
            {objXmon[11],objYmon[11]} <= {10'd471,10'd72};
            {objXmon[10],objYmon[10]} <= {10'd519,10'd72};
            {objXmon[9],objYmon[9]}   <= {10'd87,10'd112};
            {objXmon[8],objYmon[8]}   <= {10'd135,10'd112};
            {objXmon[7],objYmon[7]}   <= {10'd183,10'd112};
            {objXmon[6],objYmon[6]}   <= {10'd231,10'd112};
            {objXmon[5],objYmon[5]}   <= {10'd279,10'd112};
            {objXmon[4],objYmon[4]}   <= {10'd327,10'd112};
            {objXmon[3],objYmon[3]}   <= {10'd375,10'd112};
            {objXmon[2],objYmon[2]}   <= {10'd423,10'd112};
            {objXmon[1],objYmon[1]}   <= {10'd471,10'd112};
            {objXmon[0],objYmon[0]}   <= {10'd519,10'd112};
         end
         else begin
            for(i0=29;i0>=0;i0=i0-1)begin
               if(objYmon[i0]==10'd0)                 //remain disapear state
                  {objXmon[i0],objYmon[i0]} <= {objXmon[i0],objYmon[i0]};
               else if((mon_touch[i0])||(strike[i0])) //disapear
                  {objXmon[i0],objYmon[i0]} <= 20'd0;
               else begin                             //move based on mon_move
                  case(mon_move)
                  2'd1: {objXmon[i0],objYmon[i0]} <= {objXmon[i0]-10'd24,objYmon[i0]}; //move left 24 pixels
                  2'd2: {objXmon[i0],objYmon[i0]} <= {objXmon[i0]+10'd24,objYmon[i0]}; //move right 24 pixels
                  2'd3: {objXmon[i0],objYmon[i0]} <= {objXmon[i0],objYmon[i0]+10'd40}; //move down 40 pixels
                  2'd0: {objXmon[i0],objYmon[i0]} <= {objXmon[i0],objYmon[i0]};        //hold
                  endcase
               end
            end
         end
      end
      EPI2:begin
         if(cs==EPI1)begin //initial position (only ten monsters)
            {objXmon[9],objYmon[9]} <= {10'd87,10'd152};
            {objXmon[8],objYmon[8]} <= {10'd135,10'd152};
            {objXmon[7],objYmon[7]} <= {10'd183,10'd152};
            {objXmon[6],objYmon[6]} <= {10'd231,10'd152};
            {objXmon[5],objYmon[5]} <= {10'd279,10'd152};
            {objXmon[4],objYmon[4]} <= {10'd327,10'd152};
            {objXmon[3],objYmon[3]} <= {10'd375,10'd152};
            {objXmon[2],objYmon[2]} <= {10'd423,10'd152};
            {objXmon[1],objYmon[1]} <= {10'd471,10'd152};
            {objXmon[0],objYmon[0]} <= {10'd519,10'd152};
         end
         else begin
            for(i0=9;i0>=0;i0=i0-1)begin
               if(objYmon[i0]==10'd0)
                  {objXmon[i0],objYmon[i0]} <= {objXmon[i0],objYmon[i0]};
               else if((mon_touch[i0])||(strike[i0]))
                  {objXmon[i0],objYmon[i0]} <= 20'd0;
               else if(cnt_mon2==19'd0) begin //move every 6.25ms (default)
                  case(mon_move2[i0])
                  2'd0: {objXmon[i0],objYmon[i0]} <= {objXmon[i0]-1'b1,objYmon[i0]-1'b1}; //up left
                  2'd1: {objXmon[i0],objYmon[i0]} <= {objXmon[i0]-1'b1,objYmon[i0]+1'b1}; //down left
                  2'd2: {objXmon[i0],objYmon[i0]} <= {objXmon[i0]+1'b1,objYmon[i0]+1'b1}; //down right
                  2'd3: {objXmon[i0],objYmon[i0]} <= {objXmon[i0]+1'b1,objYmon[i0]-1'b1}; //up right
                  endcase
               end
               else
                  {objXmon[i0],objYmon[i0]} <= {objXmon[i0],objYmon[i0]}; //hold
            end
         end
      end
      default: begin
         for(i0=29;i0>=0;i0=i0-1)begin
            {objXmon[i0],objYmon[i0]} <= {objXmon[i0],objYmon[i0]};
         end
      end
      endcase
   end
end
//****************************************************************************
//*********************************BULLET*************************************
//****************************************************************************
always@(posedge clk_075s)begin                        //which bullet is allowed to lauch
   if(!rst) whichbul <= 20'b10000_00000_00000_00000;  //initially bullet[19]
   else     whichbul <= {whichbul[0],whichbul[19:1]}; //take turn after a while
end
always@(posedge clk)begin
   if(!rst)begin
      bul_mod  <= 20'd0;    //bullet mode: 1 is flying, 0 is storing
      bul_used <= 20'd0;    //bullet is used in this time of whichbul
   end
   else begin
      bul_used <= whichbul; //whichbul is used and reset other bul_used
      case(cs)
      EPI1,EPI2:begin
         for(i0=19;i0>=0;i0=i0-1)begin
            if((hit[i0]) || (objYbul[i0]<=10'd32)) //hit or go out of screen
               bul_mod[i0] <= 1'd0;
            else if(bul_mod[i0])                   //if it is flying, continue
               bul_mod[i0] <= bul_mod[i0];
            else if(whichbul[i0])                  //if allowed and not used, lauch
               bul_mod[i0] <= !bul_used[i0];
            else
               bul_mod[i0] <= bul_mod[i0];
         end
      end
      default: bul_mod <= bul_mod;
      endcase
   end
end
always@(posedge clk)begin //x,y coordinate of bullets
   if(!rst)begin
      for(i0=19;i0>=0;i0=i0-1) {objXbul[i0],objYbul[i0]} <= 20'd0;
   end
   else begin
      case(ns)
      EPI1,EPI2: begin
         for(i0=19;i0>=0;i0=i0-1)begin
            if(!bul_mod[i0])
               {objXbul[i0],objYbul[i0]} <= {objX+10'd13,objY+2'd3};        //store at middle of the tank
            else if(cnt_bul==17'd0)                                         //bullet velocity 1 pixel/2.38ms
               {objXbul[i0],objYbul[i0]} <= {objXbul[i0],objYbul[i0]-1'd1}; //fly straight up 1 pixel
            else
               {objXbul[i0],objYbul[i0]} <= {objXbul[i0],objYbul[i0]};      //hold
         end
      end
      default: begin
         for(i0=19;i0>=0;i0=i0-1) {objXbul[i0],objYbul[i0]} <= 20'd0;
      end
      endcase
   end
end
//****************************************************************************
//***********************************TANK*************************************
//****************************************************************************
assign en_obj_move = (cnt_obj==19'd0); //period of 6.25ms
always@(posedge clk)begin     //x coordinate of tank(y is fixed)
   if(!rst) objX <= 10'd303;  //middle position
   else begin
      case(ns)
      EPI1,EPI2:begin
         if(en_obj_move)begin //velocity 1 pixel/ 6.25ms
            if(move_l)        //read from button
               objX <= (objX<=10'd1)? objX : objX-1'b1;
            else if(move_r)
               objX <= (objX>=10'd608)? objX : objX+1'b1;
            else
               objX <= objX;
         end
         else
            objX <= objX;
      end
      default: objX <= 10'd303;
      endcase
   end
end
//****************************************************************************
//*********************************VGA_RGB************************************
//****************************************************************************
always@(*)begin
   for(i0=29;i0>=0;i0=i0-1)
      in_mon[i0] = ((X>=objXmon[i0])&&(X<=objXmon[i0]+10'd31)&&(Y>=objYmon[i0])&&(Y<=objYmon[i0]+10'd31));
    // X,Y is inside a monster (32x32)
   for(i0=19;i0>=0;i0=i0-1)
      in_bul[i0] = ((X>=objXbul[i0])&&(X<=objXbul[i0]+10'd3)&&(Y>=objYbul[i0])&&(Y<=objYbul[i0]+10'd3));
    // X,Y is inside a bullet (4x4)
   in_obj = ((X>=objX)&&(X<=objX+10'd31)&&(Y>=objY)&&(Y<=objY+10'd31));
   // X,Y is inside the tank (32x32)
   in_mid = (X>=10'd256)&&(X<=10'd383)&&(Y>=10'd176)&&(Y<=10'd303);
   // X,Y is inside the center area (128x128, for displaying text)
end
always@(posedge clk25M) begin //control VGA_RGB, based on current X,Y
   if(!rst)                     {VGA_R,VGA_G,VGA_B} <= 24'd0;
   else begin
      case(cs)
      IDLE:begin
         if(in_mid)             {VGA_R,VGA_G,VGA_B} <= start_color; //START text
         else                   {VGA_R,VGA_G,VGA_B} <= 24'hFFFFFF;  //background
      end
      EPI1,EPI2: begin
         if(Y<=10'd15) begin
            if(X>=10'd591)      {VGA_R,VGA_G,VGA_B} <= heart_color; //hearts at top right
            else                {VGA_R,VGA_G,VGA_B} <= 24'h0;       //background/hiding monsters 
         end
         else if(Y<=10'd30)     {VGA_R,VGA_G,VGA_B} <= 24'h0;       //background/hiding monsters
         else if(Y==10'd31)     {VGA_R,VGA_G,VGA_B} <= 24'hFFFFFF;  //white line
         else if(in_obj)        {VGA_R,VGA_G,VGA_B} <= obj_color;   //tank color
         else if(in_bul!=20'd0) {VGA_R,VGA_G,VGA_B} <= 24'hF8F6E7;  //bullet color
         else if(in_mon!=30'd0) {VGA_R,VGA_G,VGA_B} <= mon_color;   //moster color
         else if(Y==10'd445)    {VGA_R,VGA_G,VGA_B} <= 24'hFF0000;  //red line
         else                   {VGA_R,VGA_G,VGA_B} <= 24'h000000;  //background
      end
      WINN:begin
         if(in_mid)             {VGA_R,VGA_G,VGA_B} <= win_color;   //WIN text
         else                   {VGA_R,VGA_G,VGA_B} <= 24'h0;
      end
      LOSE:begin
         if(in_mid)             {VGA_R,VGA_G,VGA_B} <= lose_color;  //LOSE text
         else                   {VGA_R,VGA_G,VGA_B} <= 24'h0;
      end
      default:                  {VGA_R,VGA_G,VGA_B} <= 24'hFFFFFF;
      endcase
   end
end
//****************************************************************************
//******************************Objects' color********************************
//****************************************************************************
initial begin //reading images
   #1 //more stable
   $readmemh("./heart3.txt" ,heart3);    //image size 16x48
   $readmemh("./heart2.txt" ,heart2);    //image size 16x48
   $readmemh("./heart1.txt" ,heart1);    //image size 16x48
   $readmemh("./monster.txt",mon_img);   //image size 32x32
   $readmemh("./tank.txt"   ,obj_img);   //image size 32x32
   $readmemh("./START.txt"  ,start_img); //image size 128x128
   $readmemh("./WIN.txt"    ,win_img);   //image size 128x128
   $readmemh("./LOSE.txt"   ,lose_img);  //image size 128x128
end
assign sub_heart   = X-10'd591;       //X - x position of hearts
assign relaX_heart = sub_heart[5:0];  //relative_X based on current X
assign relaY_heart = Y[5:0];          //relative_Y based on current Y
assign y_heart = relaY_heart*10'd48;  //y in image
assign x_heart = {4'd0,relaX_heart};  //x in image
assign addr_heart = (addr_heart>=10'd767)? 10'd767 : y_heart+x_heart;
always@(*)begin  //hearts' color from image
   heart_color1 = heart1[addr_heart];
   heart_color2 = heart2[addr_heart];
   heart_color3 = heart3[addr_heart];
end
always@(*)begin
   case(heart)
   2'd1:    heart_color=heart_color1; //1 heart
   2'd2:    heart_color=heart_color2; //2 hearts
   default: heart_color=heart_color3; //3 hearts
   endcase
end
always@(*)begin //find x and y of currently displayed monster
   {sub_mon0,sub_mon1} = {objXmon[29],objYmon[29]};
   for(i0=28;i0>=0;i0=i0-1)begin
      if(in_mon[i0])
         {sub_mon0,sub_mon1}={objXmon[i0],objYmon[i0]};
   end
end
assign sub_mon2  = X-sub_mon0;
assign sub_mon3  = Y-sub_mon1;
assign relaX_mon = sub_mon2[4:0];    //relative_X based on current X
assign relaY_mon = sub_mon3[4:0];    //relative_Y based on current Y
assign y_mon     = {relaY_mon,5'd0}; //x32
assign x_mon     = {5'd0,relaX_mon};
assign addr_mon  = y_mon+x_mon;
//relative_X,Y of tank:
assign sub_obj0  = X-objX;
assign sub_obj1  = Y-objY;
assign relaX_obj = sub_obj0[4:0];
assign relaY_obj = sub_obj1[4:0];
assign y_obj     = {relaY_obj,5'd0};
assign x_obj     = {5'd0,relaX_obj};
assign addr_obj  = y_obj+x_obj;
always@(*)begin  //mosters and tank color from image
   mon_color = mon_img[addr_mon];
   obj_color = obj_img[addr_obj];
end
always@(*)begin //for displaying text
   sub_start0    = X-midx;
   sub_start1    = Y-midy;
   relaX_start = sub_start0[6:0];
   relaY_start = sub_start1[6:0];
   y_start       = {relaY_start,7'd0};
   x_start       = {7'd0,relaX_start};
   addr_start  = y_start+x_start;
   start_color = start_img[addr_start];
   win_color    = win_img[addr_start];
   lose_color    = lose_img[addr_start];
end
//****************************************************************************
//****************************All type of counters****************************
//****************************************************************************
always@(posedge clk)begin //clk_1Hz
   if(!rst)                         {cnt_1Hz,clk_1Hz} <= 26'd0;
   else if(cnt_1Hz==25'd24_999_999) {cnt_1Hz,clk_1Hz} <= {25'd0,!clk_1Hz};
   else                             {cnt_1Hz,clk_1Hz} <= {cnt_1Hz+1'b1,clk_1Hz};
end
always@(posedge clk_1Hz or negedge rst)begin //for delay 4s after a game
   if(!rst)                        {sum_cnt,sum_done} <= 3'd0;
   else if(sum_cnt==2'd3)          {sum_cnt,sum_done} <= 3'd1;
   else if((cs==WINN)||(cs==LOSE)) {sum_cnt,sum_done} <= {sum_cnt+1'b1,1'b0}; 
   else                            {sum_cnt,sum_done} <= 3'd0;
end
always@(*)begin
   case(tough)
   3'd0:begin
      cnt_mon_max  = 25'd24_999_999; //0.5s (40 pixels / 0.5s)
      cnt_mon2_max = 19'd312_499;    //6.25ms (1 pixel / 6.25ms)
   end
   3'd1:begin
      cnt_mon_max  = 25'd23_214_286;
      cnt_mon2_max = 19'd290_178;
   end
   3'd2:begin
      cnt_mon_max  = 25'd21_428_572;
      cnt_mon2_max = 19'd267_857;
   end
   3'd3:begin
      cnt_mon_max  = 25'd19_642_858;
      cnt_mon2_max = 19'd245_535;
   end
   3'd4:begin
      cnt_mon_max  = 25'd17_857_144;
      cnt_mon2_max = 19'd223_214;
   end
   3'd5:begin
      cnt_mon_max  = 25'd16_071_430;
      cnt_mon2_max = 19'd200_893;
   end
   3'd6:begin
      cnt_mon_max  = 25'd14_285_716;
      cnt_mon2_max = 19'd178_571;
   end
   3'd7:begin
      cnt_mon_max  = 25'd12_499_999; //0.25s
      cnt_mon2_max = 19'd156_249;    //3.125ms
   end
   endcase
end
always@(posedge clk)begin
   if(!rst)           cnt_mon <= 25'd0;
   else if(en_cnt_mon)cnt_mon <= 25'd0;
   else if(cs==EPI1)  cnt_mon <= cnt_mon+1'b1; //trigger monster move
   else if(cs==EPI2)  cnt_mon <= cnt_mon+4'd8; //trigger virtual_line fall
   else               cnt_mon <= 25'd0;
end
always@(posedge clk)begin //for bullet velocity
   if(!rst)                      cnt_bul <= 17'd0;
   else if(cnt_bul>=17'd118_999) cnt_bul <= 17'd0; //2.38ms
   else                          cnt_bul <= cnt_bul+1'b1;
end
assign en_cnt_075s = cnt_075s>=25'd24_499_999;
always@(posedge clk)begin //for shooting frequency
   if(en_cnt_075s)cnt_075s <= 25'd0;
   else           cnt_075s <= cnt_075s+1'b1+fire; //faster as fire increase
end
always@(posedge clk)begin //clock for whichbul
   if(en_cnt_075s)clk_075s <= !clk_075s;
   else           clk_075s <= clk_075s;
end
always@(*)begin
   case(move_speed)
   4'd00: cnt_obj_max = 19'd312_499; //6.25ms
   4'd01: cnt_obj_max = 19'd302_083;
   4'd02: cnt_obj_max = 19'd291_667;
   4'd03: cnt_obj_max = 19'd281_250;
   4'd04: cnt_obj_max = 19'd270_833;
   4'd05: cnt_obj_max = 19'd260_417;
   4'd06: cnt_obj_max = 19'd250_000;
   4'd07: cnt_obj_max = 19'd239_583;
   4'd08: cnt_obj_max = 19'd229_167;
   4'd09: cnt_obj_max = 19'd218_750;
   4'd10: cnt_obj_max = 19'd208_334;
   4'd11: cnt_obj_max = 19'd197_917;
   4'd12: cnt_obj_max = 19'd187_500;
   4'd13: cnt_obj_max = 19'd177_084;
   4'd14: cnt_obj_max = 19'd166_667;
   4'd15: cnt_obj_max = 19'd156_249; //3.125ms
   endcase
end
always@(posedge clk)begin //for tank velocity
   if(!rst)                      cnt_obj <= 19'd0;
   else if(cnt_obj>=cnt_obj_max) cnt_obj <= 19'd0; //default 6.25ms
   else                          cnt_obj <= cnt_obj+1'b1;
end
always@(posedge clk)begin //for monster velocity in EPI2
   if(!rst)                        cnt_mon2 <= 19'd0;
   else if(cnt_mon2>=cnt_mon2_max) cnt_mon2 <= 19'd0; //default 6.25ms
   else                            cnt_mon2 <= cnt_mon2+1'b1;
end
endmodule
//****************************************************************************
//*******************************IR Module************************************
//****************************************************************************
module IR_RECEIVE(iCLK,iRST_n,iIRDA,oDATA_READY,oDATA);
input iCLK;                          //input clk,50MHz
input iRST_n;                        //rst
input iIRDA;                         //Irda RX output decoded data
output oDATA_READY;                  //data ready
output reg [31:0] oDATA;             //output data, 32 bits
parameter IDLE = 2'b00;              //State Machine 
parameter GUIDANCE = 2'b01;    
parameter DATAREAD = 2'b10;    
parameter IDLE_DUR = 230000;         // idle_count     230000*0.02us = 4.60ms, threshold for IDLE->GUIDANCE
parameter GUIDANCE_DUR = 210000;     // guidance_count 210000*0.02us = 4.20ms, 4.5-4.2 = 0.3ms < BIT_AVAILABLE_DUR = 0.4ms,threshold for GUIDANCE->DATAREAD
parameter DATAREAD_DUR = 262143;     // data_count     262143*0.02us = 5.24ms, threshold for DATAREAD->IDLE
parameter DATA_HIGH_DUR = 41500;     // data_count     41500 *0.02us = 0.83ms, sample time from the posedge of iIRDA
parameter BIT_AVAILABLE_DUR = 20000; // data_count     20000 *0.02us = 0.4ms,  the sample bit pointer,can inhibit the interference from iIRDA signal      
reg idle_count_flag,guidance_count_flag,data_count_flag; 
reg [17:0] guidance_count,idle_count;
reg [17:0] data_count;
reg [5:0] bitcount;                  //sample bit pointer
reg [31:0] data_buf;                 //data buf
reg [31:0] data;                     //data reg
reg [1:0] state;                     //state reg
reg data_ready;                      //data ready flag
assign oDATA_READY = data_ready;
//state change between IDLE,GUIDE,DATA_READ according to irda edge or counter
always @(posedge iCLK or negedge iRST_n)begin 
   if(!iRST_n)        
      state <= IDLE;
   else 
      case (state)
         IDLE     :
            if(idle_count > IDLE_DUR)  
               state <= GUIDANCE; 
         GUIDANCE :
            if(guidance_count > GUIDANCE_DUR)
               state <= DATAREAD;
         DATAREAD :
            if((data_count >= DATAREAD_DUR) || (bitcount >= 33))
               state <= IDLE;
         default  : state <= IDLE; 
      endcase
end
//idle counter switch when iIRDA is low under IDLE state
always @(posedge iCLK or negedge iRST_n)begin   
   if(!iRST_n)
      idle_count_flag <= 1'b0;
   else if((state == IDLE) && !iIRDA)
      idle_count_flag <= 1'b1;
   else                           
      idle_count_flag <= 1'b0;                     
end
//idle counter works on iclk under IDLE state only
always @(posedge iCLK or negedge iRST_n)begin   
   if(!iRST_n)
      idle_count <= 0;
   else if(idle_count_flag)  //the counter works when the flag is 1
      idle_count <= idle_count + 1'b1;
   else  
      idle_count <= 0;       //the counter resets when the flag is 0                      
end
//state counter switch when iIRDA is high under GUIDE state
always @(posedge iCLK or negedge iRST_n)begin
   if(!iRST_n)
      guidance_count_flag <= 1'b0;
   else if((state == GUIDANCE) && iIRDA)
      guidance_count_flag <= 1'b1;
   else  
      guidance_count_flag <= 1'b0;               
end
//state counter works on iclk under GUIDE state only
always @(posedge iCLK or negedge iRST_n)begin
   if(!iRST_n)
      guidance_count <= 0;
   else if(guidance_count_flag) //the counter works when the flag is 1
      guidance_count <= guidance_count + 1'b1;
   else  
      guidance_count <= 0;      //the counter resets when the flag is 0                      
end
//data counter switch
always @(posedge iCLK or negedge iRST_n)begin
   if(!iRST_n) 
      data_count_flag <= 0;   
   else if((state == DATAREAD) && iIRDA)
      data_count_flag <= 1'b1;  
   else
      data_count_flag <= 1'b0; 
end
//data read decode counter based on iCLK
always @(posedge iCLK or negedge iRST_n)begin
   if(!iRST_n)
      data_count <= 1'b0;
   else if(data_count_flag)  //the counter works when the flag is 1
      data_count <= data_count + 1'b1;
   else 
      data_count <= 1'b0;    //the counter resets when the flag is 0
end
//data reg pointer counter 
always @(posedge iCLK or negedge iRST_n)begin
   if(!iRST_n)
      bitcount <= 6'b0;
   else if(state == DATAREAD)begin
      if(data_count == BIT_AVAILABLE_DUR)
         bitcount <= bitcount + 1'b1; //add 1 when iIRDA posedge
   end   
   else
      bitcount <= 6'b0;
end 
//data decode base on the value of data_count    
always @(posedge iCLK or negedge iRST_n)begin
   if(!iRST_n)
      data <= 0;
   else if(state == DATAREAD)begin
      if(data_count >= DATA_HIGH_DUR) //2^15 = 32767*0.02us = 0.64us
         data[bitcount-1'b1] <= 1'b1; //>0.52ms  sample the bit 1
   end
   else
      data <= 0;   
end
//set the data_ready flag 
always @(posedge iCLK or negedge iRST_n)begin 
   if(!iRST_n)
      data_ready <= 1'b0;
   else if(bitcount == 32)   begin
      if(data[31:24] == ~data[23:16])begin      
         data_buf <= data;     //fetch the value to the databuf from the data reg
         data_ready <= 1'b1;   //set the data ready flag
      end   
      else
         data_ready <= 1'b0 ;  //data error
   end
   else
      data_ready <= 1'b0 ;
end
//read data
always @(posedge iCLK or negedge iRST_n)begin
   if(!iRST_n)
      oDATA <= 32'b0000;
   else if(data_ready)
      oDATA <= data_buf;  //output
end     
endmodule
module encode (num,seven_node);
input [3:0] num;
output reg [6:0] seven_node;
always@(num)
begin
   case(num)
   4'd0: seven_node = 7'b0000001;
   4'd1: seven_node = 7'b1001111;
   4'd2: seven_node = 7'b0010010;
   4'd3: seven_node = 7'b0000110;
   4'd4: seven_node = 7'b1001100;
   4'd5: seven_node = 7'b0100100;
   4'd6: seven_node = 7'b0100000;
   4'd7: seven_node = 7'b0001111;
   4'd8: seven_node = 7'b0000000;
   4'd9: seven_node = 7'b0000100;
   4'd10: seven_node = 7'b0001000;
   4'd11: seven_node = 7'b1100000;
   4'd12: seven_node = 7'b0110001;
   4'd13: seven_node = 7'b1000010;
   4'd14: seven_node = 7'b0110000;
   default: seven_node = 7'b0111000;
   endcase
end
endmodule
module debounce(clk,a,b);
input clk;
input [11:0] a;
output reg [11:0] b;
reg [9:0] count;
always@(posedge clk)begin
   b <= b;
   if(count>=10'd1000) begin //after 20us still be different
      count <= 10'd0;
      b <= a;
   end
   else if(b!=a)
      count <= count+1'b1;
   else
      count <= 10'd0;
end
endmodule
module bin2bcd (bin,g,h);
input [7:0] bin;      //max score is 50
output reg [3:0] g,h; //only need 2 digits
integer i;
always@(*)
begin
   {g,h}=8'd0;
   for(i=7; i>=0;i=i-1)
   begin
      if(g>=4'd5)
         g = g + 2'd3;
      if(h>=4'd5)
         h = h + 2'd3;
      {g,h} = {g[2:0],h,bin[i]};
   end
end
endmodule