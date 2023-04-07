import { Component } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  constructor (private http: HttpClient){

  }
  title = 'monopoly-sql-web';

  isRegistration : boolean = false;
  token : number = 0;
  onlineNickname : string = '';
  roomsList : Array<any> = [];
  roomsListIsActive : boolean = false;
  roomCreationMenuIsActive : boolean = false;

  swapScreen(){
    this.isRegistration = !this.isRegistration;
  }

  loginToAccount(){
    let nickname = document.getElementById('nick-input') as HTMLInputElement;
    let nicknameString = nickname.value;
    let password = document.getElementById('pass-input') as HTMLInputElement;
    let passwordString = password.value;
    console.log(nicknameString, passwordString);
    
    this.http.get(`https://sql.lavro.ru/call.php?pname=sign_in&db=285312&p1=${nicknameString}&p2=${passwordString}`).subscribe((data : any) => {
      console.log('login data', data);
      let tempData : { room_id : Array<any>, player_number_limit : Array<any>, turn_time_limit : Array<any>} = data.RESULTS[2];
      this.token = data.RESULTS[0].token;
      this.onlineNickname = data.RESULTS[0].online;
      this.roomsList.push(tempData);
      this.roomsListIsActive = true;
      console.log(this.roomsList);
    });

  }

  regNewAccount(){
    let nickname = document.getElementById('nick-input') as HTMLInputElement;
    let nicknameString = nickname.value;
    let password = document.getElementById('pass-input') as HTMLInputElement;
    let passwordString = password.value;
    console.log(nicknameString, passwordString);
    
    this.http.get(`https://sql.lavro.ru/call.php?pname=player_registration&db=285312&p1=${nicknameString}&p2=${passwordString}`).subscribe((data : any) => {
      console.log('login data', data);
      let tempData : { room_id : Array<any>, player_number_limit : Array<any>, turn_time_limit : Array<any>} = data.RESULTS[2];
      this.token = data.RESULTS[0].token;
      this.onlineNickname = data.RESULTS[0].online;
      this.roomsList.push(tempData);
      this.roomsListIsActive = true;
      console.log(this.roomsList);
    });
  }

  openRoomCreationMenu(){
    this.roomCreationMenuIsActive = true;
  }

  closeRoomCreationMenu(){
    let playerLimit = document.getElementById('player-limit-input') as HTMLInputElement;
    let playerLimitValue = playerLimit.value;

    let timeLimit = document.getElementById('time-input') as HTMLInputElement;
    let timeLimitValue = timeLimit.value;

    this.http.get(`https://sql.lavro.ru/call.php?pname=create_room&db=285312&p1=${this.token}&p2=${playerLimitValue}&p3=${timeLimitValue}`).subscribe((data : any) => {
      console.log('login data', data);
      
    });
  }

}
