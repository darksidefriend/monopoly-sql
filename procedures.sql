-- https://sql.lavro.ru/call.php?pname=SignIn&db=265117&p1=temp1&p2=987654&format=columns

CREATE TABLE Users (login VARCHAR(30) PRIMARY KEY, password VARCHAR(30) NOT NULL);

CREATE TABLE Rooms (room_id INTEGER PRIMARY KEY AUTOINCREMENT, player_number_limit INTEGER NOT NULL, turn_time_limit INT NOT NULL);

CREATE TABLE Action_Cards (action_id INTEGER PRIMARY KEY AUTOINCREMENT, card_name VARCHAR(30) NOT NULL, card_color VARCHAR(30) NULL, card_value INTEGER NOT NULL);

CREATE TABLE Property_Cards (property_id INTEGER PRIMARY KEY AUTOINCREMENT, card_name VARCHAR(30) NOT NULL, card_color VARCHAR(30) NOT NULL, card_value INTEGER NOT NULL, rent INTEGER NOT NULL);

CREATE TABLE Money_Cards (money_id INTEGER PRIMARY KEY AUTOINCREMENT, card_value INTEGER NOT NULL);

CREATE TABLE Cards(card_id INTEGER PRIMARY KEY AUTOINCREMENT, room_id INTEGER NOT NULL REFERENCES Rooms(room_id) ON DELETE CASCADE, action_id INTEGER NULL REFERENCES Action_Cards(action_id) ON DELETE CASCADE, property_id INTEGER NULL REFERENCES Property_Cards(property_id) ON DELETE CASCADE, money_id INTEGER NULL REFERENCES Money_Cards(money_id) ON DELETE CASCADE);

CREATE TABLE Players(player_id INTEGER PRIMARY KEY AUTOINCREMENT, player_queue_number INTEGER NULL, room_id INTEGER NOT NULL REFERENCES Rooms(room_id) ON DELETE CASCADE, player_login VARCHAR(30) NULL REFERENCES Users(login) ON UPDATE CASCADE ON DELETE SET NULL, UNIQUE (room_id, player_login), UNIQUE (player_queue_number, room_id));

CREATE TABLE Turns (player_id INTEGER NOT NULL PRIMARY KEY REFERENCES Players(player_id) ON DELETE CASCADE, turn_end_time TIMESTAMP NOT NULL);

CREATE TABLE Player_Bank_Cards (card_id INTEGER NOT NULL PRIMARY KEY REFERENCES Cards(card_id) ON DELETE CASCADE, player_id INTEGER NOT NULL REFERENCES Players(player_id) ON DELETE CASCADE);

CREATE TABLE Player_Hand (card_id INTEGER NOT NULL PRIMARY KEY REFERENCES Cards(card_id) ON DELETE CASCADE, player_id INTEGER NOT NULL REFERENCES Players(player_id) ON DELETE CASCADE);

CREATE TABLE Player_Playing_Cards (card_id INTEGER NOT NULL PRIMARY KEY REFERENCES Cards(card_id) ON DELETE CASCADE, player_id INTEGER NOT NULL REFERENCES Players(player_id) ON DELETE CASCADE);

CREATE TABLE Player_Payment_Cards (card_id INTEGER NOT NULL PRIMARY KEY REFERENCES Cards(card_id) ON DELETE CASCADE, player_id INTEGER NOT NULL REFERENCES Players(player_id) ON DELETE CASCADE);

CREATE TABLE Player_Property_Cards (card_id INTEGER NOT NULL PRIMARY KEY REFERENCES Cards(card_id) ON DELETE CASCADE, player_id INTEGER NOT NULL REFERENCES Players(player_id) ON DELETE CASCADE);

CREATE TABLE Tokens(token INT UNSIGNED PRIMARY KEY, login VARCHAR(30) NOT NULL, date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (login) REFERENCES Users(Login))

CREATE PROCEDURE player_registration (lg VARCHAR(30), pw VARCHAR(30))
COMMENT "Регистрация игрока (логин, пароль)"
BEGIN
IF EXISTS (SELECT * FROM Users WHERE login = lg)
    THEN SELECT "Неверный логин или пароль" AS error;
    ELSE INSERT IGNORE INTO Users VALUES (lg, pw);
    SELECT "Пользователь успешно создан" as info, lg as login_name; 
END IF;
CALL sign_in(lg, pw);
END;

CREATE PROCEDURE sign_in (lg VARCHAR(30), pw VARCHAR(30))
COMMENT "Вход в систему (логин, пароль)"
BEGIN
IF EXISTS (SELECT * FROM Users WHERE login = lg AND password = pw)
    THEN IF EXISTS(SELECT * FROM Tokens WHERE login = lg) THEN
        DELETE FROM Tokens WHERE TIMESTAMPDIFF(MINUTE, date, NOW()) > 30 OR login = lg;
    END IF;
    INSERT INTO Tokens values(RAND()*256*256*256, lg, NOW());
    SELECT token FROM Tokens where login = lg ORDER BY date DESC LIMIT 1;
    SELECT DISTINCT login as online FROM Tokens WHERE TIMESTAMPDIFF(MINUTE, date, NOW()) < 5;
    SELECT * FROM Rooms AS online_rooms;

ELSE SELECT "Неверный логин или пароль" AS error;
END IF;
END;

CREATE FUNCTION `checkToken`(_token INT) RETURNS VARCHAR(30)
COMMENT 'Обновление времени токена - (токен)'
BEGIN
    DECLARE _login VARCHAR(30) DEFAULT (SELECT login FROM Tokens WHERE token = _token ORDER BY date LIMIT 1);
    IF _login IS NOT NULL THEN
        RETURN _login;
    ELSE
        RETURN NULL;
    END IF;
END;

CREATE PROCEDURE isTokenActive (_token INT)
COMMENT "Возвращает 0 или 1 в зависимости от того, активен токен или нет/просрочен"
BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);

    IF _login IS NULL THEN
        SELECT 0 AS isTokenActive;
    ELSE
        SELECT 1 AS isTokenActive;
    END IF;
END;

CREATE PROCEDURE create_room (_token INT, player_limit INT, time_limit INT)
COMMENT "Создание комнаты (кол-во игроков, ограничение времени)"
create_room: BEGIN

DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
  
IF _login IS NULL THEN
    SELECT "Ошибка авторизации" AS error;
    LEAVE create_room;
END IF;


IF player_limit < 2 OR player_limit > 4
    THEN SELECT "Недопустимое значение кол-ва игроков" AS error;
ELSEIF time_limit < 0
    THEN SELECT "Недопустимое значение ограничения времени" AS error;
ELSE
    INSERT IGNORE INTO Rooms VALUES (NULL, player_limit, time_limit);
    SELECT * FROM Rooms as active_rooms;
END IF;
    SET @room_id = (SELECT room_id FROM Rooms ORDER BY room_id DESC LIMIT 1);
    CALL enter_room(_token, @room_id);
END;

CREATE PROCEDURE enter_room(_token INT, _room_id INT)
COMMENT "Войти в комнату (токен, id комнаты)"
enter_room: BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);

    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE enter_room;
    END IF;

    IF NOT EXISTS(SELECT room_id FROM Rooms WHERE room_id = _room_id) THEN
        SELECT "Комната не существует" as error;
        LEAVE enter_room;
    END IF;

    START TRANSACTION;

        IF EXISTS(SELECT * FROM Players WHERE room_id = _room_id AND Players.player_login = _login) THEN
            SELECT "Игрок уже находится в этой комнате" as error;
            LEAVE enter_room;
        END IF;

        -- IF EXISTS(SELECT * FROM Players WHERE room_id != _room_id AND Players.player_login = _login) THEN
        --     SELECT "Игрок уже находится в другой комнате" as error;
        --     LEAVE enter_room;
        -- END IF;

        IF ((SELECT COUNT(*) FROM Players WHERE room_id = _room_id) >= (SELECT player_number_limit FROM Rooms WHERE room_id = _room_id)) THEN
            SELECT "Свободных мест в этой комнате нет" as error;
            LEAVE enter_room;
        END IF;

        IF EXISTS(SELECT * FROM Players JOIN Turns USING(player_id) WHERE room_id = _room_id AND player_queue_number IS NOT NULL) THEN
            SELECT "Игра уже запущена" as error;
            LEAVE enter_room;
        END IF;

        INSERT IGNORE INTO Players VALUES (NULL, NULL, _room_id, _login);
        COMMIT;

        SELECT player_login, player_queue_number  from Players WHERE room_id = _room_id;
END;

CREATE PROCEDURE leave_room(_token INT, _room_id INT)
COMMENT "Выход из комнаты (токен, id комнаты)"
leave_room: BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);

    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE leave_room;
    END IF;

    DELETE FROM Players WHERE room_id = _room_id AND player_login = _login;
    SELECT * FROM Rooms;
END;

CREATE PROCEDURE start_game(_token INT, _room_id INT)
COMMENT "Начало игры (токен, id комнаты)"
start_game: BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);

    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE start_game;
    END IF;

    IF (SELECT COUNT(*) FROM Players WHERE room_id = _room_id AND player_queue_number IS NOT NULL > 0) THEN
        SELECT "Игра уже началась" as error;
        LEAVE start_game;
    END IF;

    CREATE TEMPORARY TABLE PlayersOrder (orderNumber INT AUTO_INCREMENT PRIMARY KEY, loginOrder VARCHAR(30));
        INSERT INTO PlayersOrder SELECT NULL, player FROM
        (SELECT player_login as player FROM Players WHERE room_id = _room_id ) AS tempTable ORDER BY RAND();

        UPDATE Players, PlayersOrder as a
        SET player_queue_number  = orderNumber WHERE room_id = _room_id AND player_login = loginOrder;

    DROP TEMPORARY TABLE PlayersOrder;

    INSERT INTO Cards (card_id, room_id, action_id, property_id, money_id)
    SELECT NULL, _room_id, a.action_id, NULL, NULL
    FROM Action_Cards as a;

    INSERT INTO Cards (card_id, room_id, action_id, property_id, money_id)
    SELECT NULL, _room_id, NULL, p.property_id, NULL
    FROM Property_Cards as p;

    INSERT INTO Cards (card_id, room_id, action_id, property_id, money_id)
    SELECT NULL, _room_id, NULL, NULL, m.money_id
    FROM Money_Cards as m;


    INSERT INTO Turns (player_id, turn_end_time)
    SELECT player_id, NOW()
    FROM Players WHERE room_id = _room_id AND player_queue_number = 1;

    INSERT INTO Turns (player_id, turn_end_time)
    SELECT player_id, NULL
    FROM Players WHERE room_id = _room_id AND player_queue_number != 1;

   
    SET @temp = (SELECT t.token
    FROM Players p
    JOIN Tokens t
    ON p.player_login = t.login
    WHERE p.room_id = _room_id
        AND p.player_queue_number = 1);



    CALL get_cards(@temp, _room_id);


END;

CREATE PROCEDURE get_cards(_token INT, _room_id INT)
COMMENT "Получить карты в начале хода (токен)"
get_cards: BEGIN

    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);

    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE get_cards;
    END IF;


    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login AND room_id = _room_id);



    -- IF((SELECT turn_end_time FROM Turns WHERE player_id = @player_id) IS NULL) THEN
    --     SELECT "Сейчас не Ваш ход" as error;
    --     LEAVE get_cards;
    -- END IF;

    IF NOT EXISTS(SELECT * FROM Player_Hand WHERE player_id = @player_id) THEN
        SELECT "ДАЙТЕ ПЯТЬ";
        INSERT INTO Player_Hand (card_id, player_id)
        SELECT card_id, @player_id
        FROM Cards WHERE card_id NOT IN (
            SELECT card_id FROM Player_Property_Cards
            UNION
            SELECT card_id FROM Player_Bank_Cards
            UNION 
            SELECT card_id FROM Player_Payment_Cards
            UNION
            SELECT card_id FROM Player_Property_Cards
            UNION 
            SELECT card_id FROM Player_Playing_Cards
        ) ORDER BY RAND() LIMIT 5;
    
    ELSE 
        SELECT "ДАЙТЕ ДВЕ";
        INSERT INTO Player_Hand (card_id, player_id)
        SELECT card_id, @player_id
        FROM Cards WHERE card_id NOT IN (
            SELECT card_id FROM Player_Property_Cards
            UNION
            SELECT card_id FROM Player_Bank_Cards
            UNION 
            SELECT card_id FROM Player_Payment_Cards
            UNION
            SELECT card_id FROM Player_Property_Cards
            UNION 
            SELECT card_id FROM Player_Playing_Cards
        ) ORDER BY RAND() LIMIT 2;

    END IF;

    SELECT * FROM Player_Hand WHERE player_id = @player_id;

END;

CREATE PROCEDURE pass_start(_token INT, _played_card_id INT, _room_id INT)
COMMENT "Пройди через Старт(токен, id карты, id комнаты)"
pass_start:BEGIN
    
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);

    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE pass_start;
    END IF;

    

    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login AND room_id = _room_id);

    IF((SELECT turn_end_time FROM Turns WHERE player_id = @player_id) IS NULL) THEN
        SELECT "Сейчас не Ваш ход" as error;
        LEAVE pass_start;
    END IF;

    IF (TIMESTAMPDIFF(SECOND, (SELECT turn_end_time FROM Turns WHERE player_id = @player_id), NOW()) > (SELECT turn_time_limit FROM Rooms WHERE room_id = @room_id)) THEN
        CALL next_turn(_token, _room_id);
        LEAVE steal_trade;
    END IF;

    START TRANSACTION;

    INSERT INTO Player_Hand (card_id, player_id)
    SELECT card_id, @player_id
    FROM Cards WHERE card_id NOT IN (
        SELECT card_id FROM Player_Property_Cards
        UNION
        SELECT card_id FROM Player_Bank_Cards
        UNION 
        SELECT card_id FROM Player_Payment_Cards
        UNION
        SELECT card_id FROM Player_Property_Cards
        UNION 
        SELECT card_id FROM Player_Playing_Cards
    ) ORDER BY RAND() LIMIT 2;

    INSERT INTO Player_Playing_Cards VALUES (_played_card_id, @player_id);
    DELETE FROM Player_Hand WHERE card_id = _played_card_id AND player_id = @player_id;

    COMMIT;

    IF ((SELECT COUNT(*) FROM (SELECT * FROM Player_Playing_Cards WHERE player_id = @player_id) as cnt )  = 3) THEN
        CALL next_turn(_token);
        DELETE FROM Player_Playing_Cards WHERE player_id = @player_id;
    END IF;

    SELECT * FROM Player_Hand WHERE player_id = @player_id;

    CALL get_game_status(_token, _room_id);

END;

CREATE PROCEDURE next_turn(_token INT, _room_id INT)
COMMENT "Передача хода (токен)"
next_turn: BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
    
    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE next_turn;
    END IF;

    START TRANSACTION;

    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login AND room_id = _room_id);
    SET @current_turn_number = (SELECT player_queue_number FROM Players WHERE player_id = @player_id);

    CALL check_finish(_token, _room_id);

    UPDATE Turns
    JOIN Players USING(player_id)
    JOIN Rooms USING(room_id)
    SET turn_end_time = NOW() WHERE player_queue_number = @current_turn_number MOD player_number_limit + 1 AND room_id = _room_id;

    UPDATE Turns
    JOIN Players USING(player_id)
    JOIN Rooms USING(room_id)
    SET turn_end_time = NULL WHERE player_queue_number = @current_turn_number AND room_id = _room_id;

    COMMIT;

    SELECT * FROM Turns;

    CALL get_cards(_token, _room_id);
    
END;

CREATE PROCEDURE rent(_token INT, _rent_card_id INT, _property_card_id int, _opponent_id INT, _room_id INT)
COMMENT "Рента (токен, id карты, id оппонента, id комнаты)"
rent: BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
    
    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE rent;
    END IF;


    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login AND room_id = _room_id);
    SET @rentCardColor = (SELECT card_color FROM Action_Cards JOIN Cards USING(action_id) WHERE card_id = _rent_card_id);
    SET @propertyCardColor = (SELECT card_color FROM Property_Cards JOIN Cards USING(property_id) WHERE card_id = _property_card_id);

    IF((SELECT turn_end_time FROM Turns WHERE player_id = @player_id) IS NULL) THEN
        SELECT "Сейчас не Ваш ход" as error;
        LEAVE rent;
    END IF;
    

    IF (@rentCardColor != @propertyCardColor) THEN
        SELECT "Цвет карты ренты и карты собственности не совпадает" as error;
        LEAVE rent;
    END IF;

    IF (TIMESTAMPDIFF(SECOND, (SELECT turn_end_time FROM Turns WHERE player_id = @player_id), NOW()) > (SELECT turn_time_limit FROM Rooms WHERE room_id = @room_id )) THEN
        CALL next_turn(_token);
        LEAVE rent;
    END IF;

    IF EXISTS(SELECT * FROM Player_Hand JOIN Cards USING (card_id) JOIN Action_Cards USING (action_id) WHERE card_name = "Просто скажи Нет" AND player_id = _opponent_id) THEN
        START TRANSACTION;

        SELECT "Оппонент использовал карту Просто скажи Нет" as error;
        SET @noCardID = (SELECT card_id FROM Player_Hand JOIN Cards USING (card_id) JOIN Action_Cards USING (action_id) WHERE card_name = "Просто скажи Нет" AND player_id = _opponent_id LIMIT 1);
        DELETE FROM Player_Hand WHERE card_id = @noCardID AND player_id = _opponent_id LIMIT 1;
        INSERT INTO Player_Playing_Cards VALUES (_rent_card_id, @player_id);
        DELETE FROM Player_Hand WHERE card_id = _rent_card_id AND player_id = @player_id;

        COMMIT;

        IF ((SELECT COUNT(*) FROM (SELECT * FROM Player_Playing_Cards WHERE player_id = @player_id) as cnt )  = 3) THEN
            CALL next_turn(_token);
            DELETE FROM Player_Playing_Cards WHERE player_id = @player_id;
        END IF;

        SELECT * FROM Player_Hand WHERE player_id = @player_id;
        LEAVE rent;

    ELSE

        START TRANSACTION;

        IF @propertyCardColor = "brown" THEN 
            SET @rentAmount = (SELECT SUM(rent) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "brown" AND player_id = @player_id ORDER BY rent DESC LIMIT 2) as tmpBrown);
            SET @csum := 0;
            CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
            INSERT INTO moneyTransferCards SELECT card_id, @player_id
            FROM (SELECT card_id, (@csum := @csum + card_value) as cumulative_sum FROM (SELECT * FROM Player_Bank_Cards JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id) WHERE player_id = _opponent_id ORDER BY card_value ASC) as temp WHERE @csum < @rentAmount) AS rp;

            UPDATE Player_Bank_Cards, moneyTransferCards AS mny
            SET player_id = mplayer_id WHERE card_id = mcard_id;
            
            DROP TEMPORARY TABLE moneyTransferCards;

        ELSEIF @propertyCardColor = "lightblue" THEN
            SET @rentAmount = (SELECT SUM(rent) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "lightblue" AND player_id = @player_id ORDER BY rent DESC LIMIT 3) as tmpLightblue);
            SELECT @rentAmount;
            SET @csum := 0;
            CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
            INSERT INTO moneyTransferCards SELECT card_id, @player_id
            FROM (SELECT card_id, (@csum := @csum + card_value) as cumulative_sum FROM (SELECT * FROM Player_Bank_Cards JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id) WHERE player_id = _opponent_id ORDER BY card_value ASC) as temp WHERE @csum < @rentAmount) AS rp;

            UPDATE Player_Bank_Cards, moneyTransferCards AS mny
            SET player_id = mplayer_id WHERE card_id = mcard_id;

            DROP TEMPORARY TABLE moneyTransferCards;

        ELSEIF @propertyCardColor = "red" THEN
            SET @rentAmount = (SELECT SUM(rent) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "red" AND player_id = @player_id ORDER BY rent DESC LIMIT 3) as tmpRed);
            SET @csum := 0;
            CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
            INSERT INTO moneyTransferCards SELECT card_id, @player_id
            FROM (SELECT card_id, (@csum := @csum + card_value) as cumulative_sum FROM (SELECT * FROM Player_Bank_Cards JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id) WHERE player_id = _opponent_id ORDER BY card_value ASC) as temp WHERE @csum < @rentAmount) AS rp;

            UPDATE Player_Bank_Cards, moneyTransferCards AS mny
            SET player_id = mplayer_id WHERE card_id = mcard_id;

            DROP TEMPORARY TABLE moneyTransferCards;

        ELSEIF @propertyCardColor = "yellow" THEN
            SET @rentAmount = (SELECT SUM(rent) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "yellow" AND player_id = @player_id ORDER BY rent DESC LIMIT 3) as tmpYellow);
            SET @csum := 0;
            CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
            INSERT INTO moneyTransferCards SELECT card_id, @player_id
            FROM (SELECT card_id, (@csum := @csum + card_value) as cumulative_sum FROM (SELECT * FROM Player_Bank_Cards JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id) WHERE player_id = _opponent_id ORDER BY card_value ASC) as temp WHERE @csum < @rentAmount) AS rp;

            UPDATE Player_Bank_Cards, moneyTransferCards AS mny
            SET player_id = mplayer_id WHERE card_id = mcard_id;

            DROP TEMPORARY TABLE moneyTransferCards;

        ELSEIF @propertyCardColor = "blue" THEN
            SET @rentAmount = (SELECT SUM(rent) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "blue" AND player_id = @player_id ORDER BY rent DESC LIMIT 2) as tmpBlue);
            SET @csum := 0;
            CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
            INSERT INTO moneyTransferCards SELECT card_id, @player_id
            FROM (SELECT card_id, (@csum := @csum + card_value) as cumulative_sum FROM (SELECT * FROM Player_Bank_Cards JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id) WHERE player_id = _opponent_id ORDER BY card_value ASC) as temp WHERE @csum < @rentAmount) AS rp;

            UPDATE Player_Bank_Cards, moneyTransferCards AS mny
            SET player_id = mplayer_id WHERE card_id = mcard_id;

            DROP TEMPORARY TABLE moneyTransferCards;

        ELSEIF @propertyCardColor = "green" THEN
            SET @rentAmount = (SELECT SUM(rent) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "green" AND player_id = @player_id ORDER BY rent DESC LIMIT 3) as tmpGreen);
            SET @csum := 0;
            CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
            INSERT INTO moneyTransferCards SELECT card_id, @player_id
            FROM (SELECT card_id, (@csum := @csum + card_value) as cumulative_sum FROM (SELECT * FROM Player_Bank_Cards JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id) WHERE player_id = _opponent_id ORDER BY card_value ASC) as temp WHERE @csum < @rentAmount) AS rp;

            UPDATE Player_Bank_Cards, moneyTransferCards AS mny
            SET player_id = mplayer_id WHERE card_id = mcard_id;

            DROP TEMPORARY TABLE moneyTransferCards;

        ELSEIF @propertyCardColor = "station" THEN
            SET @rentAmount = (SELECT SUM(rent) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "station" AND player_id = @player_id ORDER BY rent DESC LIMIT 4) as tmpStation);
            SET @csum := 0;
            CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
            INSERT INTO moneyTransferCards SELECT card_id, @player_id
            FROM (SELECT card_id, (@csum := @csum + card_value) as cumulative_sum FROM (SELECT * FROM Player_Bank_Cards JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id) WHERE player_id = _opponent_id ORDER BY card_value ASC) as temp WHERE @csum < @rentAmount) AS rp;

            UPDATE Player_Bank_Cards, moneyTransferCards AS mny
            SET player_id = mplayer_id WHERE card_id = mcard_id;

            DROP TEMPORARY TABLE moneyTransferCards;

        ELSEIF @propertyCardColor = "community" THEN
            SET @rentAmount = (SELECT SUM(rent) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "community" AND player_id = @player_id ORDER BY rent DESC LIMIT 2) as tmpCommunity);
            SET @csum := 0;
            CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
            INSERT INTO moneyTransferCards SELECT card_id, @player_id
            FROM (SELECT card_id, (@csum := @csum + card_value) as cumulative_sum FROM (SELECT * FROM Player_Bank_Cards JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id) WHERE player_id = _opponent_id ORDER BY card_value ASC) as temp WHERE @csum < @rentAmount) AS rp;

            UPDATE Player_Bank_Cards, moneyTransferCards AS mny
            SET player_id = mplayer_id WHERE card_id = mcard_id;

            DROP TEMPORARY TABLE moneyTransferCards;

        END IF;

        INSERT INTO Player_Playing_Cards VALUES (_rent_card_id, @player_id);
        DELETE FROM Player_Hand WHERE card_id = _rent_card_id AND player_id = @player_id;

        COMMIT;

        IF ((SELECT COUNT(*) FROM (SELECT * FROM Player_Playing_Cards WHERE player_id = @player_id) as cnt )  = 3) THEN
            CALL next_turn(_token);
            DELETE FROM Player_Playing_Cards WHERE player_id = @player_id;
        END IF;

        SELECT * FROM Player_Hand WHERE player_id = @player_id;

        CALL get_game_status(_token);
        
    END IF;

END;

CREATE PROCEDURE birthday(_token INT, _birthday_id INT)
COMMENT "Статус игры (токен)"
current_status: BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
    
    
    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE next_turn;
    END IF;

    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login);




    IF ((SELECT COUNT(*) FROM (SELECT * FROM Player_Playing_Cards WHERE player_id = @player_id) as cnt )  = 3) THEN
         CALL next_turn(_token);
         DELETE FROM Player_Playing_Cards WHERE player_id = @player_id;
    END IF;

    SELECT * FROM Player_Hand WHERE player_id = @player_id;




END;

CREATE PROCEDURE debt_collector(_token INT, _debt_id INT, _opponent_id INT, _room_id INT)
COMMENT "Статус игры (токен)"
debt_collector: BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
    
    
    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE debt_collector;
    END IF;

    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login AND room_id = _room_id);

    IF((SELECT turn_end_time FROM Turns WHERE player_id = @player_id) IS NULL) THEN
        SELECT "Сейчас не Ваш ход" as error;
        LEAVE debt_collector;
    END IF;

    START TRANSACTION;

    IF EXISTS(SELECT * FROM Player_Hand JOIN Cards USING (card_id) JOIN Action_Cards USING (action_id) WHERE card_name = "Просто скажи Нет" AND player_id = _opponent_id) THEN
        SELECT "Оппонент использовал карту Просто скажи Нет" as error;
        SET @noCardID = (SELECT card_id FROM Player_Hand JOIN Cards USING (card_id) JOIN Action_Cards USING (action_id) WHERE card_name = "Просто скажи Нет" AND player_id = _opponent_id LIMIT 1);
        DELETE FROM Player_Hand WHERE card_id = @noCardID AND player_id = _opponent_id LIMIT 1;
        INSERT INTO Player_Playing_Cards VALUES (_debt_id, @player_id);
        
        DELETE FROM Player_Hand WHERE card_id = _debt_id AND player_id = @player_id;

    ELSE

        SET @csum := 0;
    
        CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
        INSERT INTO moneyTransferCards SELECT card_id, @player_id
        FROM (SELECT card_id, (@csum := @csum + card_value) as cumulative_sum FROM (SELECT * FROM Player_Bank_Cards JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id) WHERE player_id = _opponent_id ORDER BY card_value ASC) as temp WHERE @csum < 5) AS rp;

        UPDATE Player_Bank_Cards, moneyTransferCards AS mny
        SET player_id = mplayer_id WHERE card_id = mcard_id;

        DROP TEMPORARY TABLE moneyTransferCards;

        INSERT INTO Player_Playing_Cards VALUES (_debt_id , @player_id);
        DELETE FROM Player_Hand WHERE card_id = _debt_id AND player_id = @player_id;

    END IF;

    COMMIT;

    IF ((SELECT COUNT(*) FROM (SELECT * FROM Player_Playing_Cards WHERE player_id = @player_id) as cnt )  = 3) THEN
         CALL next_turn(_token);
         DELETE FROM Player_Playing_Cards WHERE player_id = @player_id;
    END IF;

    SELECT * FROM Player_Hand WHERE player_id = @player_id;

END;

CREATE PROCEDURE unfair_trade(_token INT, _unfair_card_id INT, _property_card_id INT, _opponent_id INT, _room_id INT)
COMMENT "Нечестная сделка (токен, id карты действия, id карты собственности, id оппонента)"
unfair_trade: BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
    
    
    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE unfair_trade;
    END IF;

    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login AND room_id = _room_id);
    SET @propertyCardColor = (SELECT card_color FROM Property_Cards JOIN Cards USING(property_id) WHERE card_id = _property_card_id);

    IF((SELECT turn_end_time FROM Turns WHERE player_id = @player_id) IS NULL) THEN
        SELECT "Сейчас не Ваш ход" as error;
        LEAVE unfair_trade;
    END IF;

    IF (TIMESTAMPDIFF(SECOND, (SELECT turn_end_time FROM Turns WHERE player_id = @player_id), NOW()) > (SELECT turn_time_limit FROM Rooms WHERE room_id = @room_id )) THEN
        CALL next_turn(_token);
        LEAVE unfair_trade;
    END IF;




    IF EXISTS(SELECT * FROM Player_Hand JOIN Cards USING (card_id) JOIN Action_Cards USING (action_id) WHERE card_name = "Просто скажи Нет" AND player_id = _opponent_id) THEN
        SELECT "Оппонент использовал карту Просто скажи Нет" as error;
        SET @noCardID = (SELECT card_id FROM Player_Hand JOIN Cards USING (card_id) JOIN Action_Cards USING (action_id) WHERE card_name = "Просто скажи Нет" AND player_id = _opponent_id LIMIT 1);
        DELETE FROM Player_Hand WHERE card_id = @noCardID AND player_id = _opponent_id LIMIT 1;
        INSERT INTO Player_Playing_Cards VALUES (_unfair_card_id, @player_id);
        DELETE FROM Player_Hand WHERE card_id = _unfair_card_id AND player_id = @player_id;

    ELSE

        START TRANSACTION;

        IF @propertyCardColor = "brown" THEN 
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) = 2) THEN
                SELECT "Нельзя брать карту из полного набора" as error;
                ROLLBACK;
                LEAVE unfair_trade;
            ELSE
                UPDATE Player_Property_Cards
                SET player_id = @player_id WHERE card_id = _property_card_id;

                COMMIT;

            END IF;

        ELSEIF @propertyCardColor = "lightblue" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) = 3) THEN
                SELECT "Нельзя брать карту из полного набора" as error;
                ROLLBACK;
                LEAVE unfair_trade;
            ELSE
                UPDATE Player_Property_Cards
                SET player_id = @player_id WHERE card_id = _property_card_id;

                COMMIT;
            END IF;

        ELSEIF @propertyCardColor = "red" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) = 3) THEN
                SELECT "Нельзя брать карту из полного набора" as error;
                ROLLBACK;
                LEAVE unfair_trade;
            ELSE
                UPDATE Player_Property_Cards
                SET player_id = @player_id WHERE card_id = _property_card_id;

                COMMIT;
            END IF;

        ELSEIF @propertyCardColor = "yellow" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) = 3) THEN
                SELECT "Нельзя брать карту из полного набора" as error;
                ROLLBACK;
                LEAVE unfair_trade;
            ELSE
                UPDATE Player_Property_Cards
                SET player_id = @player_id WHERE card_id = _property_card_id;

                COMMIT;
            END IF;

        ELSEIF @propertyCardColor = "blue" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) = 2) THEN
                SELECT "Нельзя брать карту из полного набора" as error;
                ROLLBACK;
                LEAVE unfair_trade;
            ELSE
                UPDATE Player_Property_Cards
                SET player_id = @player_id WHERE card_id = _property_card_id;

                COMMIT;
            END IF;

        ELSEIF @propertyCardColor = "green" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) = 3) THEN
                SELECT "Нельзя брать карту из полного набора" as error;
                ROLLBACK;
                LEAVE unfair_trade;
            ELSE
                UPDATE Player_Property_Cards
                SET player_id = @player_id WHERE card_id = _property_card_id;

                COMMIT;
            END IF;

        ELSEIF @propertyCardColor = "station" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) = 4) THEN
                SELECT "Нельзя брать карту из полного набора" as error;
                ROLLBACK;
                LEAVE unfair_trade;
            ELSE
                UPDATE Player_Property_Cards
                SET player_id = @player_id WHERE card_id = _property_card_id;

                COMMIT;
            END IF;

        ELSEIF @propertyCardColor = "community" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) = 2) THEN
                SELECT "Нельзя брать карту из полного набора" as error;
                ROLLBACK;
                LEAVE unfair_trade;
            ELSE
                UPDATE Player_Property_Cards
                SET player_id = @player_id WHERE card_id = _property_card_id;

                COMMIT;
            END IF;

        END IF;

    END IF;

    INSERT INTO Player_Playing_Cards VALUES (_unfair_card_id, @player_id);
    DELETE FROM Player_Hand WHERE card_id = _unfair_card_id AND player_id = @player_id;

    IF ((SELECT COUNT(*) FROM (SELECT * FROM Player_Playing_Cards WHERE player_id = @player_id) as cnt )  = 3) THEN
         CALL next_turn(_token);
         DELETE FROM Player_Playing_Cards WHERE player_id = @player_id;
    END IF;

    SELECT * FROM Player_Hand WHERE player_id = @player_id;

END;

CREATE PROCEDURE steal_trade(_token INT, _steal_card_id INT, _property_card_id INT, _opponent_id INT, _room_id INT)
COMMENT "Сорви сделку (токен, id карты действия, id карты собственности, id оппонента)"
steal_trade: BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
    
    
    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE steal_trade;
    END IF;

    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login AND room_id = _room_id);
    SET @propertyCardColor = (SELECT card_color FROM Property_Cards JOIN Cards USING(property_id) WHERE card_id = _property_card_id);

    IF((SELECT turn_end_time FROM Turns WHERE player_id = @player_id) IS NULL) THEN
        SELECT "Сейчас не Ваш ход" as error;
        LEAVE steal_trade;
    END IF;

    IF (TIMESTAMPDIFF(SECOND, (SELECT turn_end_time FROM Turns WHERE player_id = @player_id), NOW()) > (SELECT turn_time_limit FROM Rooms WHERE room_id = @room_id )) THEN
        CALL next_turn(_token);
        LEAVE steal_trade;
    END IF;



    IF EXISTS(SELECT * FROM Player_Hand JOIN Cards USING (card_id) JOIN Action_Cards USING (action_id) WHERE card_name = "Просто скажи Нет" AND player_id = _opponent_id) THEN
        SELECT "Оппонент использовал карту Просто скажи Нет" as error;
        SET @noCardID = (SELECT card_id FROM Player_Hand JOIN Cards USING (card_id) JOIN Action_Cards USING (action_id) WHERE card_name = "Просто скажи Нет" AND player_id = _opponent_id LIMIT 1);
        DELETE FROM Player_Hand WHERE card_id = @noCardID AND player_id = _opponent_id LIMIT 1;
        INSERT INTO Player_Playing_Cards VALUES (_steal_card_id, @player_id);
        DELETE FROM Player_Hand WHERE card_id = _steal_card_id AND player_id = @player_id;

    ELSE

        START TRANSACTION;

        IF @propertyCardColor = "brown" THEN 
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) >= 2) THEN
                CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
                INSERT INTO moneyTransferCards SELECT card_id, @player_id
                FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC LIMIT 2) AS rp;

                UPDATE Player_Property_Cards, moneyTransferCards AS mny
                SET player_id = mplayer_id WHERE card_id = mcard_id;

                DROP TEMPORARY TABLE moneyTransferCards;
                COMMIT;
            ELSE
                SELECT "Украсть можно только полный набор" as error;
                ROLLBACK;
                LEAVE steal_trade;
            END IF;

        ELSEIF @propertyCardColor = "lightblue" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) >= 3) THEN
                CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
                INSERT INTO moneyTransferCards SELECT card_id, @player_id
                FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC LIMIT 3) AS rp;

                UPDATE Player_Property_Cards, moneyTransferCards AS mny
                SET player_id = mplayer_id WHERE card_id = mcard_id;

                DROP TEMPORARY TABLE moneyTransferCards;
                COMMIT;
            ELSE
                SELECT "Украсть можно только полный набор" as error;
                ROLLBACK;
                LEAVE steal_trade;
            END IF;

        ELSEIF @propertyCardColor = "red" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) >= 3) THEN
                CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
                INSERT INTO moneyTransferCards SELECT card_id, @player_id
                FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC LIMIT 3) AS rp;

                UPDATE Player_Property_Cards, moneyTransferCards AS mny
                SET player_id = mplayer_id WHERE card_id = mcard_id;

                DROP TEMPORARY TABLE moneyTransferCards;
                COMMIT;
            ELSE
                SELECT "Украсть можно только полный набор" as error;
                ROLLBACK;
                LEAVE steal_trade;
            END IF;

        ELSEIF @propertyCardColor = "yellow" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) >= 3) THEN
                CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
                INSERT INTO moneyTransferCards SELECT card_id, @player_id
                FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC LIMIT 3) AS rp;

                UPDATE Player_Property_Cards, moneyTransferCards AS mny
                SET player_id = mplayer_id WHERE card_id = mcard_id;

                DROP TEMPORARY TABLE moneyTransferCards;
                COMMIT;
            ELSE
                SELECT "Украсть можно только полный набор" as error;
                ROLLBACK;
                LEAVE steal_trade;
            END IF;

        ELSEIF @propertyCardColor = "blue" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) >= 2) THEN
                CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
                INSERT INTO moneyTransferCards SELECT card_id, @player_id
                FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC LIMIT 2) AS rp;

                UPDATE Player_Property_Cards, moneyTransferCards AS mny
                SET player_id = mplayer_id WHERE card_id = mcard_id;

                DROP TEMPORARY TABLE moneyTransferCards;
                COMMIT;
            ELSE
                SELECT "Украсть можно только полный набор" as error;
                ROLLBACK;
                LEAVE steal_trade;
            END IF;

        ELSEIF @propertyCardColor = "green" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) >= 3) THEN
                CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
                INSERT INTO moneyTransferCards SELECT card_id, @player_id
                FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC LIMIT 3) AS rp;

                UPDATE Player_Property_Cards, moneyTransferCards AS mny
                SET player_id = mplayer_id WHERE card_id = mcard_id;

                DROP TEMPORARY TABLE moneyTransferCards;
                COMMIT;
            ELSE
                SELECT "Украсть можно только полный набор" as error;
                ROLLBACK;
                LEAVE steal_trade;
            END IF;

        ELSEIF @propertyCardColor = "station" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) >= 4) THEN
                CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
                INSERT INTO moneyTransferCards SELECT card_id, @player_id
                FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC LIMIT 4) AS rp;

                UPDATE Player_Property_Cards, moneyTransferCards AS mny
                SET player_id = mplayer_id WHERE card_id = mcard_id;

                DROP TEMPORARY TABLE moneyTransferCards;
                COMMIT;
            ELSE
                SELECT "Украсть можно только полный набор" as error;
                ROLLBACK;
                LEAVE steal_trade;

            END IF;

        ELSEIF @propertyCardColor = "community" THEN
            IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC) as tmpBrown) >= 2) THEN
                CREATE TEMPORARY TABLE moneyTransferCards (mcard_id INT, mplayer_id INT);
                INSERT INTO moneyTransferCards SELECT card_id, @player_id
                FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = @propertyCardColor AND player_id = _opponent_id ORDER BY rent DESC LIMIT 2) AS rp;

                UPDATE Player_Property_Cards, moneyTransferCards AS mny
                SET player_id = mplayer_id WHERE card_id = mcard_id;

                DROP TEMPORARY TABLE moneyTransferCards;
                COMMIT;
            ELSE
                SELECT "Украсть можно только полный набор" as error;
                ROLLBACK;
                LEAVE steal_trade;

            END IF;

        END IF;

    END IF;

    INSERT INTO Player_Playing_Cards VALUES (_steal_card_id, @player_id);
    DELETE FROM Player_Hand WHERE card_id = _steal_card_id AND player_id = @player_id;

    IF ((SELECT COUNT(*) FROM (SELECT * FROM Player_Playing_Cards WHERE player_id = @player_id) as cnt )  = 3) THEN
         CALL next_turn(_token);
         DELETE FROM Player_Playing_Cards WHERE player_id = @player_id;
    END IF;

    CALL get_game_status(_token);

END;

CREATE PROCEDURE get_game_status(_token INT, _room_id INT)
COMMENT "Статус игры (токен)"
get_game_status: BEGIN

    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
    
    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE get_game_status;
    END IF;

    SET @player_id = (SELECT player_id FROM Players WHERE room_id = _room_id AND player_login = _login);
    
    SET @current_turn_number = (SELECT player_queue_number FROM Players WHERE player_id = @player_id);
    SET @turnEndTime = (SELECT turn_end_time FROM Turns JOIN Players USING (player_id) WHERE player_id = @player_id);
    SET @turnTimeLimit = (SELECT turn_time_limit FROM Rooms WHERE room_id = _room_id);

    SELECT turn_time_limit FROM Rooms WHERE room_id = _room_id ;

    SELECT (SELECT turn_time_limit FROM Rooms WHERE room_id = _room_id) - TIMESTAMPDIFF(SECOND, (SELECT turn_end_time FROM Turns WHERE player_id = @player_id), NOW()) as "Оставшееся время на ход";

    SELECT * FROM Turns JOIN Players USING(player_id) WHERE turn_end_time IS NOT NULL AND room_id = _room_id;

    SELECT "Карты действия в руке", card_id, card_name, card_color, card_value from Player_Hand JOIN Cards USING (card_id) JOIN Action_Cards USING (action_id)
    WHERE player_id = @player_id ;

    SELECT "Карты денег в руке", card_id, card_value from Player_Hand JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id)
    WHERE player_id = @player_id ;


    SELECT "Карты собственности в руке", card_id, card_name, card_color, card_value, rent from Player_Hand JOIN Cards USING (card_id)JOIN Property_Cards USING (property_id)
    WHERE player_id = @player_id ;


    SELECT "Карты в банке", card_id, card_value from Player_Bank_Cards JOIN Cards USING (card_id) JOIN Money_Cards USING (money_id)
    WHERE player_id = @player_id ;

    SELECT "Открытая собственность", card_id, card_name, card_color, card_value, rent from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id)
    WHERE player_id = @player_id ;

    SELECT "Чужая открытая собственность", card_id, card_name, card_color, card_value, rent from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id)
    WHERE player_id != @player_id ;

    CALL checkTurn(_token, _room_id);

END;

CREATE PROCEDURE checkTurn(_token INT, rm_id INT)
COMMENT "Проверка завершённости хода"
checkTurn:BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);

    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE checkTurn;
    END IF;

    SET @player_id = (SELECT player_id FROM Players WHERE room_id = rm_id AND player_login = _login);
    IF (TIMESTAMPDIFF(SECOND, (SELECT turn_end_time FROM Turns WHERE player_id = @player_id), NOW()) > (SELECT turn_time_limit FROM Rooms WHERE room_id = rm_id)) THEN
    SELECT "Переход хода";
    CALL next_turn(_token, rm_id);
    END IF;
END;

CREATE PROCEDURE property(_token INT, _property_id INT, _room_id INT)
COMMENT "Использовать карту собственности (токен, id карты)"
property: BEGIN

    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
    
    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE property;
    END IF;

    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login AND room_id = _room_id);
    -- SET @room_id = (SELECT room_id FROM Rooms JOIN Players USING (room_id) WHERE player_id = @player_id);
    SET @current_turn_number = (SELECT player_queue_number FROM Players WHERE player_login = _login);

    IF((SELECT turn_end_time FROM Turns WHERE player_id = @player_id) IS NULL) THEN
        SELECT "Сейчас не Ваш ход" as error;
        LEAVE property;
    END IF;
    

    IF (TIMESTAMPDIFF(SECOND, (SELECT turn_end_time FROM Turns WHERE player_id = @player_id), NOW()) > (SELECT turn_time_limit FROM Rooms WHERE room_id = _room_id )) THEN
        CALL next_turn(_token);
        LEAVE property;
    END IF;
    
    START TRANSACTION;

    INSERT INTO Player_Property_Cards VALUES (_property_id, @player_id);
    INSERT INTO Player_Playing_Cards VALUES (_property_id, @player_id);
    DELETE FROM Player_Hand WHERE card_id = _property_id;

    COMMIT;

    IF ((SELECT COUNT(*) FROM (SELECT * FROM Player_Playing_Cards WHERE player_id = @player_id) as cnt )  = 3) THEN
         CALL next_turn(_token);
         DELETE FROM Player_Playing_Cards WHERE player_id = @player_id;
    END IF;

END;

CREATE PROCEDURE put_money(_token INT, _money_id INT, _room_id INT)
COMMENT "Использовать карту собственности (токен, id карты)"
put_money: BEGIN

    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
    
    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE put_money;
    END IF;
    

    IF((SELECT turn_end_time FROM Turns WHERE player_id = @player_id) IS NULL) THEN
        SELECT "Сейчас не Ваш ход" as error;
        LEAVE put_money;
    END IF;

    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login AND room_id = _room_id);
    -- SET @room_id = (SELECT room_id FROM Rooms JOIN Players USING (room_id) WHERE player_id = @player_id);
    SET @current_turn_number = (SELECT player_queue_number FROM Players WHERE player_login = _login);

    IF (TIMESTAMPDIFF(SECOND, (SELECT turn_end_time FROM Turns WHERE player_id = @player_id), NOW()) > (SELECT turn_time_limit FROM Rooms WHERE room_id = _room_id )) THEN
        CALL next_turn(_token);
        LEAVE put_money;
    END IF;
    
    START TRANSACTION;

    INSERT INTO Player_Bank_Cards VALUES (_money_id, @player_id);
    INSERT INTO Player_Playing_Cards VALUES (_money_id, @player_id);

    COMMIT;

    IF ((SELECT COUNT(*) FROM (SELECT * FROM Player_Playing_Cards WHERE player_id = @player_id) as cnt )  = 3) THEN
         CALL next_turn(_token);
         DELETE FROM Player_Playing_Cards WHERE player_id = @player_id;
    END IF;

END;

CREATE PROCEDURE check_finish(_token INT, _room_id INT)
COMMENT "Окончание игры (токен)"
check_finish: BEGIN
    DECLARE _login VARCHAR(30) DEFAULT checkToken(_token);
    
    IF _login IS NULL THEN
        SELECT "Ошибка авторизации" as error;
        LEAVE check_finish;
    END IF;

    SET @player_id = (SELECT player_id FROM Players WHERE player_login = _login AND room_id = _room_id);

    SET @propertyCounter := 0;

    IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "blue" AND player_id = @player_id ORDER BY rent DESC) as tmpBrown) >= 3) THEN
      SELECT @propertyCounter := @propertyCounter + 1;
    END IF;
    IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "station" AND player_id = @player_id ORDER BY rent DESC) as tmpBrown) >= 4) THEN
       SELECT @propertyCounter := @propertyCounter + 1;
    END IF;
    IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "community" AND player_id = @player_id ORDER BY rent DESC) as tmpBrown) >= 2) THEN
      SELECT  @propertyCounter := @propertyCounter + 1;
    END IF;
    IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "orange" AND player_id = @player_id ORDER BY rent DESC) as tmpBrown) >= 3) THEN
      SELECT  @propertyCounter := @propertyCounter + 1;
    END IF;
    IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "brown" AND player_id = @player_id ORDER BY rent DESC) as tmpBrown) >= 2) THEN
      SELECT  @propertyCounter := @propertyCounter + 1;
    END IF;
    IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "red" AND player_id = @player_id ORDER BY rent DESC) as tmpBrown) >= 3) THEN
      SELECT  @propertyCounter := @propertyCounter + 1;
    END IF;
    IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "yellow" AND player_id = @player_id ORDER BY rent DESC) as tmpBrown) >= 3) THEN
      SELECT  @propertyCounter := @propertyCounter + 1;
    END IF;
    IF ((SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "green" AND player_id = @player_id ORDER BY rent DESC) as tmpBrown) >= 4) THEN
      SELECT  @propertyCounter := @propertyCounter + 1;
    END IF;
    IF (SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "pink" AND player_id = @player_id ORDER BY rent DESC) as tmpBrown) >= 3 THEN
      SELECT  @propertyCounter := @propertyCounter + 1;
    END IF;
    IF (SELECT COUNT(*) FROM (SELECT * from Player_Property_Cards JOIN Cards USING (card_id) JOIN Property_Cards USING (property_id) WHERE card_color = "lightblue" AND player_id = @player_id ORDER BY rent DESC) as tmpBrown) >= 3 THEN
      SELECT  @propertyCounter := @propertyCounter + 1;
    END IF;

    IF @propertyCounter >= 3 THEN

        SELECT "Победитель" as winner, player_login FROM Players WHERE player_id = @player_id;

        DELETE FROM Turns;
        DELETE FROM Player_Hand;
        DELETE FROM Player_Bank_Cards;
        DELETE FROM Player_Property_Cards;
        DELETE FROM Player_Payment_Cards;
        DELETE FROM Player_Playing_Cards;

        UPDATE Players
        SET player_queue_number = NULL;

        SELECT player_login, player_queue_number FROM Rooms;

    END IF;

END;









