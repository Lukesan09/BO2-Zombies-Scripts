// chatbank.gsc
//
// bank script where everything actually works (.d .w .money .pay)
//
// uses players guid and creates text files with their guid
//
// 1. t6 utils required
// 2. create "bank" directory in t6 folder. program automatically creates files for new players


#include common_scripts\utility;
#include maps\_utility;

init()
{
        level thread bankOnPlayerConnect();
        level thread bankOnPlayerSay();
}

bankOnPlayerConnect()
{
    for (;;)
    {
        level waittill("connected", player);
        player thread setupBank();
    }
}

setupBank() // Initialize bank value
{
    self endon("disconnect");
    level endon("end_game");
    path = "bank/" + self getGuid() + ".txt";
    if (!fileExists(path))
    {
        /*
            Each player will have his or her own file containing the value of the bank
            This system decreases the search for an O(1) time information. 
            Direct access to information without use of any search algortim.
        */
        writeFile(path, "");
        while(!fileExists(path)) wait 0.5;

        // Set default bank value to 0
        file = fopen(path, "a");
        fwrite(file, "0");
        fclose(file);
        self.pers["bank"] = 0;  
    }
    else
        self.pers["bank"] = int(readFile(path)); // Read value from the file
}

bankOnPlayerSay()
{
    level endon("end_game");
   
    prefix = ".";
    for (;;)
    {
        level waittill("say", message, player);
        if (isDefined(player.afterlife) && player.afterlife)
        {
          player tell("Can't access bank while in afterlife");
          continue;
        }
        player.pers["bank"] = player getBankValue(); // updates player.pers just in case someones file was edited outside the game

        message = toLower(message);
        if(!level.intermission && message[0] == prefix)
        {
            args = strtok(message, " ");
            command = getSubStr(args[0], 1);
            switch(command) {
                case "deposit":
                case "d":
                    doDeposit(player, args);
                    break;

                case "withdraw":
                case "w":
                    doWhitdraw(player, args);
                    break;
            
                case "balance":
                case "b":
                case "money":
                    if (isDefined(player.pers["bank"]))
                        player tell("your balance is ^2$" + valueToString(player.pers["bank"], player));
                    break;
                case "p":
                case "pay":
                    doPay(player, args);
                break;
            }
        }
    }
}

doWhitdraw(player, args)
{
    if ((isDefined(player.whos_who_effects_active) && player.whos_who_effects_active) || (isDefined(player.fake_death) && player.fake_death))
        player tell("^1NO... ^7command disabled during last stand with WhosWho perk");
    else
    {
        if (isDefined(args[1]))
        {
            if (args[1] == "all")
            {
                diff = 1000000 - player.score;
                if (diff < player.pers["bank"])
                {
                    player.score = player.score + diff;
                    player tell("successfully withdrew ^2$" + valueToString(diff) + "^7 from your bank!");
                    newBank = player.pers["bank"] - diff;
                    player.pers["bank"] = newBank;
                    player updateBankValue(newBank);
                }
                else
                {
                    player.score = player.score + player.pers["bank"];
                    player tell("successfully withdrew ^2$" + valueToString(player.pers["bank"]) + "^7 from your bank!");
                    player.pers["bank"] = 0;
                    player updateBankValue(0);
                }
            }
            else
            {
                if (isInteger(args[1]) && args[1] > 0 && player.pers["bank"] >= int(args[1]))
                {
                    money = player.score + int(args[1]);
                    if (money > 1000000)
                    {
                        withdrawAmount = 1000000 - player.score;
                        player.score = 1000000;
                        player.pers["bank"] = player.pers["bank"] - withdrawAmount;
                        player updateBankValue(player.pers["bank"]);
                        player tell("successfully withdrew ^2$" + valueToString(withdrawAmount) + "^7 from your bank!");
                    }
                    else
                    {
                        player.score = player.score + int(args[1]);
                        player.pers["bank"] = int(player.pers["bank"]) - int(args[1]);
                        player updateBankValue(player.pers["bank"]);
                        player tell("successfully withdrew ^2$" + valueToString(args[1]) + "^7 from your bank!");
                    }
                }
                else
                    player tell("not enough money in bank");
            }
        }
        else
            player tell("Usage: ^2.w ^7<amount|all>");
    }
}
doDeposit(player, args)
{
    if (isDefined(args[1]))
    {
        if (args[1] == "all")
        {
            score = player.score;
            player.pers["bank"] = player.pers["bank"] + player.score;
            player.score = 0;
            player updateBankValue(player.pers["bank"]);
            player tell("successfully deposited ^2$" + valueToString(score) + "^7 into your bank!");
        }
        else
        {
            if (isInteger(args[1]) && player.score >= int(args[1]) && player.score > 0)
            {
                player.pers["bank"] = int(player.pers["bank"]) + int(args[1]);
                player.score = player.score - int(args[1]);
                player updateBankValue(player.pers["bank"]);
                player tell("successfully deposited ^2$" + valueToString(args[1]) + "^7 into your bank!");
            }
            else
                player tell("not enough money");
        }
    }
    else
        player tell("Usage: ^2.d ^7<amount|all>");
}

doPay(player, args)  // pay player by player name (pay from bank, not points)
{
    if ((isDefined(player.whos_who_effects_active) && player.whos_who_effects_active) || (isDefined(player.fake_death) && player.fake_death)) // Prevent money dupe
    {
        player tell("Command disabled during last stand with WhosWho perk");
    }
    else
    {
        if (isDefined(args[1]))
        {
            if (isDefined(args[2]))
            {
                if (isInteger(args[2]))
                {
                    payamount = int(args[2]);
                    playerbank = player.pers["bank"];
                    if (playerbank >= payamount)
                    {
                        targetname = args[1];

                        targetname = ToLower(targetname); 
                        foundTarget = player;

                        foreach (target in level.players)
                        {
                            if ((issubstr(ToLower(target.name), targetname) || issubstr(targetname, ToLower(target.name))) && foundTarget == player)
                                foundTarget = target;
                        }
                        if (foundTarget != player)
                        {
                            player.pers["bank"] = player.pers["bank"] - payamount;
                            player updateBankValue(player.pers["bank"]);
                            player tell("Successfully sent ^1$" + valueToString(payamount) + "^7 to " + targetname);
                            wait 0.5;
                            foundTarget.pers["bank"] = foundTarget.pers["bank"] + payamount;
                            foundTarget updateBankValue(foundTarget.pers["bank"]);
                            wait 0.5;
                            foundTarget tell(player.name + " sent ^2$" + valueToString(payamount) + " ^7 to your account.");
                        }
                        else if(issubstr(ToLower(player.name), targetname) || issubstr(targetname, ToLower(player.name)))
                        {
                            wait 0.2;
                            player tell("You can't pay yourself.");
                        }
                        else
                        {
                            wait 0.2;
                            player tell("No player with that name found.");
                            wait 1;
                            player tell("^3Usage^7: ^2.pay ^7<player> <amount>");
                        }
                    }
                    else
                        player tell("Not enough money in the bank...");
                }
                else
                    player tell("^3Usage^7: ^2.pay ^7<player> <amount>");
            }
            else
                player tell("^3Usage^7: ^2.pay ^7<player> <amount>");
        }
        else
            player tell("^3Usage^7: ^2.pay ^7<player> <amount>");
    }
}

updateBankValue( value ) // Update bank value into the file
{
    path = "bank/" + self getGuid() + ".txt";

    // Overwrite the bank value
    file = fopen( path, "w" );
    fwrite(file, value + "");
    fclose(file);
}

getBankValue()
{
    path = "bank/" + self getGuid() + ".txt";

    // Overwrite the bank value

    currentbank = int(readFile(path));
    return currentbank;
}

valueToString(value, player) // 10000 -> 10,000
{
    value = value + "";
    str = "";
    counter = 0;
    for (i = value.size - 1; i >= 0; i--)
    {
        if (counter == 3)
        {
            str = str + ",";
            counter = 0;
        }
        str = str + value[i];
        counter = counter + 1;
    }

    final = "";

    for (i = str.size - 1; i >= 0; i--)
        final = final + str[i];

    return final;
}

isInteger( value ) // Check if the value contains only numbers
{
    new_int = int(value);
    
    if (value != "0" && new_int == 0) // 0 means its invalid
        return 0;
    
    if(new_int > 0)
        return 1;
    else
        return 0;
}

// bonus functions, can be used in other scripts, include this file in other scripts and use these if you wanna give or take money
// player/self give_player_amount(1000)

give_player_amount(amount)
{
    self.pers["bank"] = self getBankValue();
    self.pers["bank"] = int(self.pers["bank"]) + amount;
    self updateBankValue(self.pers["bank"]);
    self tell("successfully deposited ^2$" + valueToString(amount) + "^7 into your bank!");
}

take_player_amount(amount)
{
    self.pers["bank"] = self getBankValue();
    self.pers["bank"] = int(self.pers["bank"]) - amount;
    self updateBankValue(self.pers["bank"]);
    self tell("successfully withdrew ^1$" + valueToString(amount) + "^7 from your bank!");
}
