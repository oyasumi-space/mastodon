/*
 * Please don't remove this long comment for something.
 *
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 *
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 * 
 */

setTimeout(() => {
  const print = (str) => {
    // eslint-disable-next-line no-console
    console.log('%c' + str, 'font-size: 0.5rem; font-family: monospace;');
  }

  const something = [
    "............. ...   ............................... ..... ............. ..... ..",
    "...........           .    ..       .   . .. ...    .  ..     .. ...    .  ..   ",
    "...........   ..     .     .  .    OOZZZZZO    .    ..  ...  ...   .    ..  ... ",
    "...........                .. .OZZZZZZZZZZZZZO,     .   .     ..  ..    .   .   ",
    "............. ..  . .  .    ZZZZZZZZZZZZZZZZZZZZO.... ... ... ... ... ... ... ..",
    "............. ...   ... ?ZZZZZZZZZZZZZZZZZZZZZZZMMZO......  ........ .........  ",
    "....................  MZZZZZZZZZZZZZZZZZZZZZZZZZZZMZZZ .........................",
    ".....  .  .........MMMZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ........................",
    "   . .    ....... OZZMMZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ$......................",
    "   . .    .......ZZZOMMMMMMMMMZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ ....................",
    " . . .    ......NZZMNMMMMMMMMMMNNZZMMMNMOMMOM8ZZZZZZZZZZZZZZI...................",
    " .   . . ......OMZZZMMMMMMMMMMMMMZZZMMMMMMZZMZZZZZZZZZZZZZZZZ...................",
    ".. ... .. ....MZZZOMMMMMMMMMMMMMMZNMMMMMMMZMMZZZZZZZZZZZZZZZZZ, ................",
    ".............MMZMZZZZMMMMZMMMMMMMMMMZZMMMMMZZZZZZZZMZZMOZZZMMZZ~................",
    "   ..   . ..=MMZMMMZMZZMZOMMMMMMMMMMMMMMMMZZZZZZZZZZZZMOZMMMMZZZ................",
    "............MOMZNOOOMMMMZZDONMMMMMMMMMMMOOZZMDZOZOMOZZNNNMMMMMMOZ~..............",
    "    . . . .ZMMMZZZZMZZZMMMDMMMMMMMMMMMMMMZZZZZMDOZMZOMMMZMOMZMZZZZ .............",
    " .  ..  . MZMMZZZMZZZOZOZZZMOMMMMMMMMMZZZMMMMZZ8MMMMMMZZMZZMZMMZZZZ.............",
    "..........ZMZZOZOZZZMZZMZZDONMMMMMMMMM.,OMMMZZMMMMMMMMMMMMMMMMMMMZZ ............",
    " .  .    ZMOMZOMOMMMMZZMMZDOMOOMMMOMM=.. ,MMMMMMMMMMMZMMMZMMMMMMMMZI............",
    ".. ...  ZOMMMMMMMMMMMMZOZMDO8ZMMOMMMZ.....MMMMMMMMMMMMMMMMMMMMMMMMOZ............",
    "........ZZMMZMMMMMMZZMMZZMMMMZMMMMMM,. ...IMMMMMMMMMMMMMMMMMMMMMMMMZ$...........",
    ".......8ZZMMMMMMMOMMZZMMZZZZZMMMMMM7.......IMMMMMMMMMMMMMMMMMMMMMMMOZ...........",
    ". .... O8DMMDDDZZMMOODOZZZDZDDDZMD~.........MMMMMMMMMMMMMMMMMMMMMMMMD...........",
    " .  ..MMZOMMMOMZZMMZZMMZZOZZMMMZMZ:.........,MMMMMMMMMMMMMMMMMMMMMMMMO .........",
    "..... MNZZZZZMMZZMOZZZZZZZDZZZZMZM. .........OMMMMMMMMMMMMMMMMMMMMMMOM .........",
    "......MNZZZZZZZZZ8NZZZZNZZ8ZZZNM8~. .........~MMMMMMMM8M8ZMMMMMMMMMMM8 .........",
    ".....MMNZZZZZZZZMZMOMMONOMMZOMZZ..............~MMMMMMZMOMMZMMZMZOMMMMMZ.........",
    "....IMMMDDZZZZDZDDMZDMMMMMNDDMOZ...............=MMDDZMDZ8DOZZZZZZZDMDMM ........",
    "....MMMZZMZZZZMMMMMMMMMOMZMMMZM:.............. =ZMMMZMZZZZZZZZZZZZZMZZM:........",
    "....MMMMOZMMZMMZZMMMMMMMMMMMMOZ.................IMMMMMOZZZZZZZZZZZZZZZZM........",
    "...MMMNOON8MMNMMMMMMMMMMMMMMMM...................ZMZO88ZNZZZZZZZZZZZZNMN8.......",
    "...MMZMNZZMMMMMMMMMMMMMMMMMMMM. ................,+MZZMMMZMOZZMOZZZZOZZZZO.......",
    "...MMZMNOMMMMMMMMMMMMMMMMMMMMZ. ..................MMZMZMZZMMMZMOZZDZZZZZM.......",
    ".. MMMMMMMMMMMMMMMMMMMMMMMMMM. ...................MMMMMMMMMMMMMMMZDZZZZZZ+......",
    "..MMMMMMMMMMMMMMMMMMMMMMMMMMM................... .=MMMMMMMMMMMMMMODMMMZZZO .....",
    "..MMMMMMMMMMMMMMMMMMMMMMMMMMN. ...... ~+..........,MMOZMMZMMMMMMMMMMNMOZZZ,.....",
    ". MMMMMMMMMMMMMMMMMMMMMMMMMMN. ...,ZTHERE'SM,...... MMMMMMOZMMMMMMMMMMMMZMO.....",
    ". MMMMMMMMMMMMMMMMMMMMMMMMMMD, ...NSOMETHINGM.......MZMMMMZMMMMMMMMMMMMMMMM.....",
    ".MMMMMMMMMMMMMMMMMMMMMMMMMMMD ....MMBEHINDMMM,......M8MDMMNMMMMMMMMMMMMMMMM.....",
    ". MMMMMMMMMMMMMMMMMMMMMMMMMMD.....MMMMYOUMMMM .... .ZZMZOMMMMMMMMMMMMMMMMMM.....",
    ". MMMMMMMMMMMMMMMMMMMMMMMMMMM.....:MMMMMMMMM.......MZOMOMZMOMMMMMMMMMMMMMMM.....",
    ". MMMMMMMMMMMMMMMMMMMMMMMMMMMI......=?MMMM.........MMMZMMMOZMZMMMMMMMMMMZZZ.....",
    ".,MMMMMMMMMMMMMMMMMMMMMMMMMMMM.....................MMMMMMMMMZZMOMMMMMMMMMMO.....",
    ".MMMMMMMMMMMMMMMMMMMMMMMMMMMMM....................+MMMMMMMMMDZMD8MDDMMMMMMD.....",
    ".MMMMMMMMMMMMMMMMMMMMMMMMMMMMM.................. .MMMMMMMMMMZMMMMMDMNMMMMZZ.....",
    ".MMMMMMMMMMMMMMMMMMMMMMMMMMMMM.................. .MMMMMMMMMMMMMMMMMMOMMMZZZM....",
    ".MMMMMMMMMMMMMMMMMMMMMMMMMMMMM, .... ............ZMMMMMMMMMMMMMMMMMMMMMMMZMM....",
    " MMMMMMMMMMMMMMMMMMMMMMMMMMMMMZ,.................MMMMMMMMMMMMMMMMMDMMMMMZOMM....",
    ".MMMMMMMMMMMMMMMMMMMMMMMMMMMMMM.................ZMMMMMMMMMMMMMMMMMMMMMMMMMOM....",
    ". MMMMMMMMMMMMMMMMMMMMMMMMMMMMMM...............:MMMMMMMMMMMMMMMMMMMMMMMMMZZZ....",
    "..MMMMMMMMMMMMMMMMMMMMMMMMMMMMMM...............+MMMMMMMMMMMMMMMMMMMMMMMMZZZZ....",
    "..MMMMMMMMMMMMMOMMZMMMMMMMMMMMMM .............=MMMMMMMMMMMMMMMMMMMMMMMMMZZZZ....",
    "..MMMMMMMMMMMMMMZZMMMMMMMMMMMMMMZ,.......... OMMMMMMMMMMMMMMMMMMMMMMZMMZZZZZ....",
    ".. MMMMMMMMMMMMOOZMMMMMMMMMMMMMMMZ: .........MMMMMMMMMMMMMMMMMMMMMMMOMMMZZZZI...",
    ".. MMNMM8MMNODZZO8MMMMMMMMMMMMMMMMZ:........MMMMMMMMMM8MMMMMMMMMNMM88ZM8ZZZZ+...",
    ".. MMMZ8MZZZMZZZZMMMMMMMMMMMMMMMMMMZ.......IMMMMMMMMMMMMMMMMMMMOMMDMZZZZZZZZZ...",
    "..MMMMMMM$OOZZZZOMMMMMMMMMMMMMMMMMMM.... .OMMMMMMMMMMMMMMMMMMMMMMZZOZZZZZZZZZ...",
    "..MMMMZNOZZZZZZZZMZZMMMMMMMMMMMMMMMM=. ..=MMMMMMMMMMMMMMMMMMNMZZZMZZZZZMMZZZZ...",
    "..MMMMM8ZZZZZZZZMMMMMMMMMMMMMMMMMMMMMM .IMMMMMMMMMMMMMMMZMMMMMMZZMDMZOZMZZZZZ...",
    "..MMMMMNNNZZZZZN8ZDMMMMMMMMMMMMMMMMMMM..MMMMMMMMMMMMMMMM8MMDMNZMMNMM88ZZZZZZZ...",
    "..MMMMMMMMZZZZZZMZMMMMMMMMMMMMMMMMMMMMZZMMMMMMMMMMMMMMMMMZZMMMOMMMMMZMMZZZZZZ ..",
    "..MMMMMMMZZMZZZMZMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMOMMMMMMMMMMZMZZZZ ..",
    "...MMMMMMMZMOMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZMMMMMMMDMMOOMMMMZZ ..",
    "...MMMMMZMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZMMZMZZ ..",
    "...MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZMMMMMMMMMMMMMMMMMMMMMMMMZZ ..",
    "...MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM...",
    "...MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZMMMMMMMMMMMMMMMMMMMMMMM...",
    "...MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM ..",
    "....MMMMMMMMMMMMMMMOZOMMMMMMOMZZMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM...",
    "....MMMMMMMMMMMZMMMMMMMMMMMMMMZMMMMMMMMMMMMMMMMMMMMMMMMMMZMMMMMMMMMMMMMMMMMMM...",
    "....MMMMMMMMMMMMMMMMMMMZZZDZOMZZMZZZZZMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM...",
    "....MMMMMMMMMMMMMMMMMMMMMMMMNOZZZZZZZZZMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM...",
    "....MMMMMMMMMMMMMMMMMMMMMMMZMOZZZZZZZZZZMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM7...",
    "....MMMMMMMMMMMMMMMMMMMMMMMMMMMMZZZZZZZZZOMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM7...",
    "....DMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZZZZZZZMMMMMNZZZMMMMMMMMMMMMMMMMMMMMMMMMZ....",
    "....DMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZZZZZZZZZMMM8MZZZZZZMMMMMMMMMMMMMMMMMMMMZ....",
    ".... MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZZZZZZZZDMMMZZZZZZMMMMMMMMMMZMOMMMMMMMM....",
    ".....MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZZZZZZZMMMMMZZZZZMMMMMMMMMMMMMOMMMMMMM....",
    ".... MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZZZZZMZ8ONOZZZZMMMMMMMMMMMMMMOMMMMMM....",
    ".....MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZZMZZOZZZZZZM=...,MMMMMMMMMMMMMMM....",
    "..... MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZ8ZOZZZZZZ. .....MMMMMMMOMMMMMMM....",
    "......MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMZMMOZZZZZZZM .......MZOMMMMMMMMMMM....",
    "......MMMMMMMMMMM. ..... MMMMMMMMMMMMMMMMMMMMZZZZZZZZ..........MMMMMMMMMMMMM....",
    "......MMMZMMMMMM..........MMMMMMMMMMMMMMMMMMMMZZZZZZM..........NMMMMMMMMMMMM....",
    "......MMZMZMMMM=...... . ..MMMMMMMMMMMMMMMMMMDODZMMM.. .. ......MMMMMMMMMMMM. ..",
    "......MMZ$ZMMMM............MMMMMMMMMMMMMMMMMMNMMONM,............NMMMMMMMMMMO....",
    ".......MMOMZZOM,...... ....+MMMMMMMMMMMMMMMMMMMNMNM ............ MMMMMMMMM8Z....",
    ".......MZZZOZMO....... .....MMMMMMMMMMMMZMMMMMMMMMM..............MMMMMMMMMMM....",
    ".......MZOZZZZ .............MMMMMMMMMMMMMMZZMMMMMM.... ...........MMMMMMMMNO....",
    ".......NZMZZOM .............MMMMMMMMMMMMMMMMMMMMMM................MMMMMMMZO+....",
    ".......ZZZMZZZ ... .   .... MMMMMMMMMMMMMMMMMMMMM .... ......... .7MMMMMMOM+....",
    ".......MMZMZZN..............:MMMMMMMMMMMMMMMMMMMM,................ MMMMMOMN?....",
    ".......MMOOMM................MMMMMMMMMMMMMMMMMMMM .................MMMMMMZM+....",
    "........OMZMM ........ ..... MMMMMMMMMMMMMMMMMMMM ..................MMMMMZN+....",
    "........MMMMM...............:MMMMMMMMMMMMMMMMMMM. ..................MMMMMMM+....",
    "........MMMMM............... MMMMMMMMMMMMMMMMMMM. .... .............:MMMMMM+....",
    "........MMMMM... ..... . ....MMMMMMMMMMMMMMMMMMM. .... ......... ... MMMMMM ....",
    "........NMMM ................MMMMMMMMMMMMMMMMMM....... ..............MMMMMO.....",
    ".........MZO ......... . ....MMMMMMMMMMMMMMMMMM . ............. . .. MMMMMO.....",
    "........,O8M.......... ......MMMMMMMMMMMMMMMMMM ..................... MMMM:.....",
    ".........ZMM................ MMMMMMMMMMMMMMZM8M.......................$MMM .....",
    "........ MM... ............. MMMMMMMMMMMMMMMZNM.. ...................  MMZ......",
    "........ MM..... ..... .... .MMMMMMMMMMMMMMMMMM.. .... ......... .. . .MMM .....",
    "........ MM .......... ......MMMMMMMMMMMMMMMMM?.. .... .............. . MM .....",
    "........ 8M........... . .. .MMMMMMMMMMMMMMMMM. . .... .. ......... . ..M. .. ..",
    "........ ZM... ..............MMMMMMMMMMMMMMMMM .. ................... ..M ......",
    ".........Z ........... .... .NMMMMMMMMMMMMMMMM... ... ..... ..... ... ......... ",
    ".......... ........... ...... MMMMMMMMMMMMMMMM... ................... ..........",
    "............................. MMMMMMMMMMMMMMMM... ................... ..........",
    "............................. MMMMMMMMMMMMMMM+... ................... ..........",
    "............................. MMMMMMMMMMMMMMM...................................",
    "...................... .. ... MMMMMMMMMMMMMMM.... .... ......... .... .... .....",
    "............................. MMMMMMMMMMMMMMM.... .... ......... .... .... .....",
    "............................. MMMMMMMMMMMMMM:.... ................... ..........",
    "............................. MMMMMMMMMMMMMM..... ................... ..........",
    "............................. MMMMMMMMMMMMMM..... ................... ..........\u200b",
    "...................... ...... MMMMMMMMMMMMMM .... .............. .... ..........",
    "..................... ....... MMMMMMMMMMMMZ  .... .... ......... .... .... .....",
    "............................. MMMMOMMMMMMOM ..... ................... ..........",
    "..............................MMMMOMMMMMZMM. .... .... ......... .... .... .....",
    "..............................MMMMD8DD8OZZZ ..... .... .............. .... .....",
    "...............................MMMOZMMZZZZZ...... .... .............. .... .....",
    "...............................MMMMMZMZZZZZ ....................................",
    "..... ... ............ ....... MMZZMZZZZZZZ  .... .... ......... .... .... .....",
    "..............................$MZZZOOZZZZZZ...... ................... ..........",
    "...................... ....... ZZZOZZZZZZZ....... .... .............. .... .....",
    " ........ .....................MZZOZZZZZZZ....... ................... ..........",
    "...................... ........MZOOZZZZZZZ....... ................... ..........",
    ".....................  ........MM88ZOZNZZZ ...... .... .............. .... .....",
    "..  . ... .....................MMMZMMMMZZZO...... ................... ..........",
    "...............................MMMMOMMZ$ZM.. .... .... ......... .... .... .....",
    "...............................MMM8ZNMDMMD......................................",
    "..  ... . ............ .........MMMMMMMMMO . .... .... ......... .... .... .....",
    "................................MMMMMMMZ8M......................................",
    ".....................  ........ MMNMMMMZM. ...... .... .............. .... .....",
    "...................... .. ......MMMMMMMMZ. . .... .... ......... .... .... .....",
    "................................MMMDMMMMD ......................................",
    "................................MMMZMMOMM........ ............ ...... ..........",
    "...................... .. ...... MOOMZMM . . .... .... ......... .... .... .....",
    "...................... .... .....MMMMMMM.. ...... ................... ..........",
    ".................................MMMMZMM......... ................... ..........",
    ".................................MMMMZM ......... ................... ..........",
    ".................................MMMZOM ......... ................... ..........",
    ".................................MMMOMM  ... .... .... ......... .... .... .....",
    "...................... .. . .....MNZZZ$... ...... ............ ...... ..........",
    "................................ MMMMZ:.........................................",
    "..................... ..... ...  MMMZM... ... ... ............... ... ..........",
    "...................... ..........,MMMM.... ...... ................... ..........",
    "...................... .......... MMZM.... ...... ................... ..........",
    "..................... ..... ... ..MMM ... .. .... .............. .... ..........",
    "..................................MMM ........... ................... ..........",
    "........................... ......MMM....... .... .... ......... .... .... .....",
    "..................................MMM............ ................... ..........",
    "...................... .. ... ... MM ..... . .... .... ......... .... .... .....",
    ".....................  .... ... ..MM ....  ...... .... .............. .... .....",
    "..................................DM............. ................... ..........",
    "....... . .........................=............. ................... ..........",
    "...................................+............. ................... ..........",
    "......... ...........  ........ .... ....  . .... .... ......... .... .... .....",
    "................................................................................",
    ".. .. . . ............ ........ .... ..... ...... .... .............. .... .....",
  ];

  let index = 0;
  const intervalId = setInterval(() => {
    if (something.length <= index) {
      clearInterval(intervalId);
      return;
    }
    print(something[index]);
    index++;
  }, 16);

}, 143000);
