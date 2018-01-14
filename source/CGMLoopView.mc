/*
 * CGM Loop Garmin Connect IQ application
 * Copyright (C) 2017 tynbendad@gmail.com
 * #WeAreNotWaiting
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, version 3 of the License.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   A copy of the GNU General Public License is available at
 *   https://www.gnu.org/licenses/gpl-3.0.txt
 */
 
var REMOVE_BEFORE_POSTING_TO_GITHUB_NSURL = "https://yoursite.herokuapp.com"; // useful for build-to-USB device deployment, remove user data when releasing to store or github
var testno = 0;	 // set to 0 for release
var maxtestno = 8;
var reload = false;

using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.WatchUi as Ui;
using Toybox.Attention as Attention;
using Toybox.Timer as Timer;

// This implements CGM Loop watch face
// Original design by tynbendad@github
class CGMLoopView extends Ui.View
{
	// bitmaps:
    var dndIcon, disconnIcon;
	var dirSwitch = {};

	// app settings, defaults, NOTE: put temp. debug settings inside updateSettings():
	var version = "unknown";
	var nsurl = "";
	var showSeconds = false;
	var respectDND = false;
	var silenceGesture = true;
	var isMGDL = true;
	var dataMode = dataModeMin;
	var bgLowWarning = 80;
	var	bgHiWarning = 240;
	var	bgLowAlert = 69;
	var	bgHiAlert = 300;
	var predictLowWarning = 0;
	var	predictHiWarning = 300;
	var	predictLowAlert = -50;
	var	predictHiAlert = 400;
	var	elapsedWarning = 15;
	var	elapsedAlert = 30;
	var	pumpbatWarning = 30;
	var	pumpbatAlert = 26;
	var	pumpbatVWarning = 1.25;
	var	pumpbatVAlert = 1.1;
	var	phonebatWarning = 20;
	var	phonebatAlert = 10;
	var	reservoirWarning = 30;
	var	reservoirAlert = 10;

	// misc. constants:
	var mmolMgdlFactor = 18.018018;
	enum {
		dataModeMin = 0,
		dataModeLoop = 1,
		dataModeOpenAPS = 2 }
		

	// state:
	var myTimer;
	var timerStarted = false;
	var secondHandMS = 500;
	var nosecondHandMS = 20000;
    var font;
    var isAwake;
    var screenShape;
	var requestComplete = true;
	var elapsedOffset = 0;
	
	// state retrieved from nightscout:
	var bg=0, direction="", directionIcon=null, delta="", elapsedMills=0,
		loopstatus="", predicted="Loading...", loopElapsedSecs=0,  minPredict=null, maxPredict=null,
		pumpbat=-1, pumpbatdisplay="", phonebat=-1, reservoir=-1, iob="", cob="", basal="";
	var predictions = [];

	// warning/alert state:
	var loopstatusWarned=false, loopstatusAlerted=false,
		bgWarned=false, bgAlerted=false, predictWarned=false, predictAlerted=false, 
		elapsedWarned=false, elapsedAlerted=false, pumpbatWarned=false, pumpbatAlerted=false, 
		phonebatWarned=false, phonebatAlerted=false, reservoirWarned=false, reservoirAlerted=false;
	var silenced = false;

	function myPrintLn(x) {
		System.println(x);
	}
	
    function initialize() {
    	myPrintLn("in LoopView initialize");
        View.initialize();
        screenShape = Sys.getDeviceSettings().screenShape;

    	var thisApp = Application.getApp();
        version = thisApp.getProperty("appVersion");
        if (version != null) {
        	predicted = "V" + version;
    	}
    	
        myTimer = new Timer.Timer();
    	
    	updateSettings();

    	myPrintLn("out LoopView initialize");
	}
        
    function updateSettings() {
    	myPrintLn("in LoopView updateSettings");

    	var thisApp = Application.getApp();
    	if (thisApp.debugNoSettings) {
			nsurl = REMOVE_BEFORE_POSTING_TO_GITHUB_NSURL;
			//showSeconds = true;
			//isMGDL = false;
			dataMode = dataModeOpenAPS;
        	silenced = true;

	    	myPrintLn("early out LoopView updateSettings");

			if (timerStarted) {
				myTimer.stop();
				timerStarted = false;
			}
			viewRefreshUI();
    		return;
		}

		nsurl = thisApp.getProperty("nsurl");
		//myPrintLn(nsurl);
		showSeconds = thisApp.getProperty("showSeconds");
		//myPrintLn(showSeconds);
		respectDND = thisApp.getProperty("respectDND");
		//myPrintLn(respectDND);
		silenceGesture = thisApp.getProperty("silenceGesture");
		//myPrintLn(silenceGesture);
		isMGDL = thisApp.getProperty("isMGDL");
		//myPrintLn(isMGDL);
		bgLowWarning = thisApp.getProperty("bgLowWarning").toFloat();
		//myPrintLn(bgLowWarning);
		bgHiWarning = thisApp.getProperty("bgHiWarning").toFloat();
		//myPrintLn(bgHiWarning);
		bgLowAlert = thisApp.getProperty("bgLowAlert").toFloat();
		//myPrintLn(bgLowAlert);
		bgHiAlert = thisApp.getProperty("bgHiAlert").toFloat();
		//myPrintLn(bgHiAlert);
		predictLowWarning = thisApp.getProperty("predictLowWarning").toFloat();
		//myPrintLn(predictLowWarning);
		predictHiWarning = thisApp.getProperty("predictHiWarning").toFloat();
		//myPrintLn(predictHiWarning);
		predictLowAlert = thisApp.getProperty("predictLowAlert").toFloat();
		//myPrintLn(predictLowAlert);
		predictHiAlert = thisApp.getProperty("predictHiAlert").toFloat();
		//myPrintLn(predictHiAlert);
		elapsedWarning = thisApp.getProperty("elapsedWarning").toNumber();
		//myPrintLn(elapsedWarning);
		elapsedAlert = thisApp.getProperty("elapsedAlert").toNumber();
		//myPrintLn(elapsedAlert);
		pumpbatWarning = thisApp.getProperty("pumpbatWarning").toFloat();
		//myPrintLn(pumpbatWarning);
		pumpbatAlert = thisApp.getProperty("pumpbatAlert").toFloat();
		//myPrintLn(pumpbatAlert);
		pumpbatVWarning = thisApp.getProperty("pumpbatVWarning").toFloat();
		//myPrintLn(pumpbatWarning);
		pumpbatVAlert = thisApp.getProperty("pumpbatVAlert").toFloat();
		//myPrintLn(pumpbatAlert);
		phonebatWarning = thisApp.getProperty("phonebatWarning").toNumber();
		//myPrintLn(phonebatWarning);
		phonebatAlert = thisApp.getProperty("phonebatAlert").toNumber();
		//myPrintLn(phonebatAlert);
		reservoirWarning = thisApp.getProperty("reservoirWarning").toNumber();
		//myPrintLn(reservoirWarning);
		reservoirAlert = thisApp.getProperty("reservoirAlert").toNumber();
		//myPrintLn(reservoirAlert);
		dataMode = thisApp.getProperty("dataMode");
		//myPrintLn(dataMode);
    	
    	// force a re-load of BG data after settings update:
    	elapsedMills = 0;
    	savedMin = -1;

		if (timerStarted) {
			myTimer.stop();
			timerStarted = false;
		}
		viewRefreshUI();
	
    	myPrintLn("out LoopView updateSettings");
    }

    function viewRefreshUI() {
      	//myPrintLn("in view refreshUI");
        if (!timerStarted) {
			var timerMS;
	        if (showSeconds) {
	        	timerMS = secondHandMS;
	        } else {
	        	timerMS = nosecondHandMS;
	        }
			timerStarted = true;
		    myTimer.start(method(:viewRefreshUI), timerMS, true);
		}

    	updateView();
      	//myPrintLn("out view refreshUI");
    }

    function onLayout(dc) {
    	myPrintLn("in LoopView onLayout");
        font = /*Gfx.FONT_NUMBER_MEDIUM; //*/ Ui.loadResource(Rez.Fonts.id_font_black_diamond);
        dndIcon = Ui.loadResource(Rez.Drawables.DoNotDisturbIcon);
        if (Sys.getDeviceSettings() has :phoneConnected) {
	        disconnIcon = Ui.loadResource(Rez.Drawables.DisconnectedIcon);
        } else {
        	disconnIcon = null;
        }
		dirSwitch = { "SingleUp" => Ui.loadResource(Rez.Drawables.SingleUp),
					 	  "DoubleUp" => Ui.loadResource(Rez.Drawables.DoubleUp),
					 	  "FortyFiveUp" => Ui.loadResource(Rez.Drawables.FortyFiveUp),
					 	  "FortyFiveDown" => Ui.loadResource(Rez.Drawables.FortyFiveDown),
					 	  "SingleDown" => Ui.loadResource(Rez.Drawables.SingleDown),
					 	  "DoubleDown" => Ui.loadResource(Rez.Drawables.DoubleDown),
					 	  "Flat" => Ui.loadResource(Rez.Drawables.Flat),
					 	  "NONE" => Ui.loadResource(Rez.Drawables.NONE) };
		viewRefreshUI(); //	    myTimer.start(method(:viewRefreshUI), 1000, false);
     	
    	myPrintLn("out LoopView onLayout");
    }

    // Draw the watch hand
    // @param dc Device Context to Draw
    // @param angle Angle to draw the watch hand
    // @param length Length of the watch hand
    // @param width Width of the watch hand
    function drawHand(dc, angle, length, width) {
        // Map out the coordinates of the watch hand
        var coords = [[-(width / 2),0], [-(width / 2), -length], [width / 2, -length], [width / 2, 0]];
        var result = new [4];
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        // Transform the coordinates
        for (var i = 0; i < 4; i += 1) {
            var x = (coords[i][0] * cos) - (coords[i][1] * sin);
            var y = (coords[i][0] * sin) + (coords[i][1] * cos);
            result[i] = [centerX + x, centerY + y];
        }

        // Draw the polygon
        dc.fillPolygon(result);
        dc.fillPolygon(result);
    }

    // Draw the hash mark symbols on the watch
    // @param dc Device context
    function drawHashMarks(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Draw hashmarks differently depending on screen geometry
        if (Sys.SCREEN_SHAPE_ROUND == screenShape) {
            var sX, sY;
            var eX, eY;
            var outerRad = width / 2;
            var innerRad = outerRad - 10;
            // Loop through each 15 minute block and draw tick marks
            for (var i = Math.PI / 6; i <= 11 * Math.PI / 6; i += (Math.PI / 3)) {
                // Partially unrolled loop to draw two tickmarks in 15 minute block
                sY = outerRad + innerRad * Math.sin(i);
                eY = outerRad + outerRad * Math.sin(i);
                sX = outerRad + innerRad * Math.cos(i);
                eX = outerRad + outerRad * Math.cos(i);
                dc.drawLine(sX, sY, eX, eY);
                i += Math.PI / 6;
                sY = outerRad + innerRad * Math.sin(i);
                eY = outerRad + outerRad * Math.sin(i);
                sX = outerRad + innerRad * Math.cos(i);
                eX = outerRad + outerRad * Math.cos(i);
                dc.drawLine(sX, sY, eX, eY);
            }
        } else {
            //var coords = [0, width / 4, (3 * width) / 4, width];
            var coords = [0, width];
            for (var i = 0; i < coords.size(); i += 1) {
                var dx = ((width / 2.0) - coords[i]) / (height / 2.0);
                var upperX = coords[i] + (dx * 10);
                // Draw the upper hash marks
                dc.fillPolygon([[coords[i] - 1, 2], [upperX - 1, 12], [upperX + 1, 12], [coords[i] + 1, 2]]);
                // Draw the lower hash marks
                dc.fillPolygon([[coords[i] - 1, height-2], [upperX - 1, height - 12], [upperX + 1, height - 12], [coords[i] + 1, height - 2]]);
            }
        }
    }

	function processAlerts() {
    	myPrintLn("in LoopView processAlerts");

		loopstatusWarned=false;
		loopstatusAlerted=false;
		bgWarned=false;
		bgAlerted=false;
		predictWarned=false;
		predictAlerted=false;
		elapsedWarned=false;
		elapsedAlerted=false;
		pumpbatWarned=false;
		pumpbatAlerted=false; 
		phonebatWarned=false;
		phonebatAlerted=false;
		reservoirWarned=false;
		reservoirAlerted=false;

		if ((bg >= bgHiWarning) || (bg <= bgLowWarning)) {
			bgWarned = true;
        }
		if ((bg >= bgHiAlert) || (bg <= bgLowAlert)) {
			bgAlerted = true;
        }

		if ((maxPredict != null) && (minPredict != null)) {
			if ((maxPredict >= predictHiWarning) || (minPredict <= predictLowWarning)) {
				predictWarned = true;
	        }
			if ((maxPredict >= predictHiAlert) || (minPredict <= predictLowAlert)) {
				predictAlerted = true;
	        }
		}

        var myMoment = new Time.Moment(elapsedMills / 1000);
		var elapsedMinutes = Math.floor(Time.now().subtract(myMoment).value() / 60);
        if (elapsedMinutes >= elapsedWarning) {
        	elapsedWarned = true;
        }
        if (elapsedMinutes >= elapsedAlert) {
        	elapsedAlerted = true;
        }

		if (dataMode == dataModeOpenAPS) {
			if (((loopstatus.find("Ena") == 0) ||
				 (loopstatus.find("Loo") == 0)) &&
				!loopstatus.equals("Enacted") &&
				!loopstatus.equals("Looping")) {
				loopstatusWarned = true;
			} else if (!loopstatus.equals("Looping") &&
				!loopstatus.equals("Enacted") &&
				!loopstatus.equals("Not Ena") &&
				!loopstatus.equals("")) {
				loopstatusAlerted = true;
			}
		} else if (dataMode == dataModeLoop) {
			if (!loopstatus.equals("Looping") &&
				!loopstatus.equals("Enacted") &&
				!loopstatus.equals("Recomme") &&
				!loopstatus.equals("")) {
				loopstatusAlerted = true;
			}
		}

        if ((pumpbatdisplay.length() > 0) &&
        	pumpbatdisplay.substring(pumpbatdisplay.length()-1, pumpbatdisplay.length()).equals("%")) {
			if (pumpbat != -1) {
		        if (pumpbat <= pumpbatWarning) {
		        	pumpbatWarned = true;
		        }
		        if (pumpbat <= pumpbatAlert) {
		        	pumpbatAlerted = true;
		        }
			}
        } else {
			if (pumpbat != -1) {
		        if (pumpbat <= pumpbatVWarning) {
		        	pumpbatWarned = true;
		        }
		        if (pumpbat <= pumpbatVAlert) {
		        	pumpbatAlerted = true;
		        }
			}
        }
		
		if (phonebat != -1) {
	        if (phonebat <= phonebatWarning) {
	        	phonebatWarned = true;
	        }
	        if (phonebat <= phonebatAlert) {
	        	phonebatAlerted = true;
	        }
		}
		
		if (reservoir != -1) {
	        if (reservoir <= reservoirWarning) {
	        	reservoirWarned = true;
	        }
	        if (reservoir <= reservoirAlert) {
	        	reservoirAlerted = true;
	        }
		}
		
        if (!(silenceGesture && silenced) && (null != dndIcon) && (!(Sys.getDeviceSettings() has :doNotDisturb) || !(respectDND && Sys.getDeviceSettings().doNotDisturb)) &&
			(bgAlerted || loopstatusAlerted ||
			 predictAlerted || elapsedAlerted ||
			 pumpbatAlerted || phonebatAlerted ||
			 reservoirAlerted)) {
            if (Attention has :playTone) {
                Attention.playTone(Attention.TONE_CANARY);
	        }
            if ((Attention has :vibrate) &&
            	(Attention has :VibeProfile) &&
            	Sys.getDeviceSettings().vibrateOn) {
                var vibrateData = [
                        new Attention.VibeProfile(  25, 100 ),
                        new Attention.VibeProfile(  50, 100 ),
                        new Attention.VibeProfile(  75, 100 ),
                        new Attention.VibeProfile( 100, 100 ),
                        new Attention.VibeProfile(  75, 100 ),
                        new Attention.VibeProfile(  50, 100 ),
                        new Attention.VibeProfile(  25, 100 )
                      ];
                Attention.vibrate(vibrateData);
            }
		}

    	myPrintLn("out LoopView processAlerts");
	}

	function mmol_or_mgdl(bg) {
        if (!isMGDL) {
        	//myPrintLn("BG: " + bg);
        	bg = 10 * (bg / mmolMgdlFactor) + 0.5;
        	bg = bg.toNumber();
        	bg = bg / 10.0;
        	//myPrintLn("BG: " + bg);
        } else {
        	bg = bg.toNumber();
        }
        return bg;
    }
	
	function mmol_or_mgdl_str(bg) {
		var bgStr;
		bg = mmol_or_mgdl(bg);
        if (!isMGDL) {
        	var bgInt = bg.toNumber();
        	var bgFrac = ((bg - bgInt) * 10).toNumber();
    		bgStr = bgInt.toString() + "." + bgFrac.toString(); 
    	} else {
    		bgStr = bg.toString(); 
    	}
    	return bgStr;
    }

	function onReceive(responseCode, data) {
		myPrintLn("in onReceive()");
		//myPrintLn("response: " + responseCode.toString());
		if ((responseCode == 200) &&
			(data != null) &&
			!data.isEmpty()) {
			try {
				//myPrintLn(data.toString());
				if (data.hasKey("bgnow")) {
					if (data["bgnow"].hasKey("mills")) {
				        //myPrintLn(data["bgnow"]["mills"].toString());
				        if (elapsedMills == data["bgnow"]["mills"]) {
				        	elapsedOffset = (elapsedOffset + 1) % 5;
				        }
				        elapsedMills = data["bgnow"]["mills"];
			        } else {
			        	elapsedMills = 0;
			        }
					if (data["bgnow"].hasKey("last")) {
			            //myPrintLn(data["bgnow"]["last"].toString());
			            bg = data["bgnow"]["last"];
		            } else {
		            	bg = 0;
		            }
					bg = mmol_or_mgdl(bg);
		            if (data["bgnow"].hasKey("sgvs") &&
		            	(data["bgnow"]["sgvs"].size() > 0) &&
		            	data["bgnow"]["sgvs"][0].hasKey("direction")) {
				        //myPrintLn(data["bgnow"]["sgvs"][0]["direction"].toString());
				        direction = data["bgnow"]["sgvs"][0]["direction"].toString();
	/*					var dirSwitch = { "SingleUp" => "^",
									 	  "DoubleUp" => "^^",
									 	  "FortyFiveUp" => "/",
									 	  "FortyFiveDown" => "\\",
									 	  "SingleDown" => "v",
									 	  "DoubleDown" => "vv",
									 	  "Flat" => "-",
									 	  "NONE" => "--" };
			        	if (dirSwitch.hasKey(direction)) {
			        		direction = dirSwitch[direction];
			        		//myPrintLn(direction);
			        	} else {
			        		direction = "?";
			        	}
	 */
			        	if (dirSwitch.hasKey(direction)) {
			        		directionIcon = dirSwitch[direction];
			        		//myPrintLn(direction);
			        	} else {
				        	directionIcon = null;
			        	}
	 		        } else {
			        	direction = "";
			        	directionIcon = null;
			        }
	            }
				if (data.hasKey("delta") &&
					data["delta"].hasKey("display")) {
		            //myPrintLn(data["delta"]["display"].toString());
		            delta = data["delta"]["display"].toString();
	            } else {
		            delta = "";
	            }

				// piggyback on basal line for now - rawbg is too much for some watches (vivoactive) to read with openaps currently, anyway...
				if (data.hasKey("rawbg") &&
					data["rawbg"].hasKey("mgdl") &&
					data["rawbg"].hasKey("noiseLabel")) {
		            basal = "raw:" + data["rawbg"]["mgdl"].toString() + " " + data["rawbg"]["noiseLabel"];
	            } else {
		            //nothing
	            }
	            
				if (data.hasKey("cob") &&
					data["cob"].hasKey("display")) {
		            //myPrintLn(data["cob"]["display"].toString());
		            cob = data["cob"]["display"].toNumber().toString() + "g";
	            } else {
	            	cob = "";
	            }
	
				if (data.hasKey("iob") &&
					data["iob"].hasKey("display")) {
		            //myPrintLn(data["iob"]["display"].toString());
		            iob = data["iob"]["display"].toString() + "U";
	            	if ((iob.toString().find("0U") != null) &&
	            		(iob.toString().find("0U") != 0)) {
	            		iob = iob.toString().substring(0, iob.toString().find("0U")) + "U";
	            	}
	            } else {
	            	iob = "";
	            }
	        
				if (data.hasKey("basal") &&
					data["basal"].hasKey("display")) {
		            //myPrintLn(data["basal"]["display"].toString());
	            	basal = data["basal"]["display"].toString();
	            	if (basal.toString().find("T: ") == 0) {
	            		basal = "T:" + basal.toString().substring(3, basal.toString().length());
	            	}
	            	if (basal.toString().find("0U") != null) {
	            		basal = basal.toString().substring(0, basal.toString().find("0U")) + "U";
	            	}
	            	if (basal.toString().find("0U") != null) {
	            		basal = basal.toString().substring(0, basal.toString().find("0U")) + "U";
	            	}
	        	} else {
	        		// hang on to the last basal, it should be more relevant than nothing
	        		// basal = "";
	        	}
	
	        	minPredict = null;
	        	maxPredict = null;
	            if (data.hasKey("loop") &&
	                data["loop"].hasKey("lastLoop") &&
	                (data["loop"]["lastLoop"] != null)) {
	            	if (data["loop"].hasKey("display") &&
		            	data["loop"]["display"].hasKey("label")) {
		            	//myPrintLn(data["loop"]["display"]["label"].toString());
	    	        	loopstatus = data["loop"]["display"]["label"].toString();
	    	        	var statuslen = loopstatus.length();
	    	        	if (statuslen > 7) {
	    	        		statuslen = 7;
		        		}
	    	        	loopstatus = loopstatus.substring(0, statuslen);
		        	} else {
		        		loopstatus = "";
			        }
			        if (data["loop"].hasKey("lastPredicted") &&
			        	(data["loop"]["lastPredicted"] != null) &&
			        	data["loop"]["lastPredicted"].hasKey("values") &&
			        	data["loop"]["lastPredicted"].hasKey("startDate")) {
						var numPredictions = data["loop"]["lastPredicted"]["values"].size();
	            		//myPrintLn(data["loop"]["lastPredicted"]["startDate"].toString());
						var loopTime = data["loop"]["lastPredicted"]["startDate"].toString();
						var options = { :year => loopTime.substring(0,4).toNumber(),
										:month => loopTime.substring(5,7).toNumber(),
										:day => loopTime.substring(8,10).toNumber(),
										:hour => loopTime.substring(11,13).toNumber(),
										:minute => loopTime.substring(14,16).toNumber(),
										:second => loopTime.substring(17,19).toNumber() };
						var moment = Calendar.moment(options);
						//var clockTime = System.getClockTime();
						//myPrintLn("timezoneoffset=" + clockTime.timeZoneOffset.toString());
						//var offset = new Time.Duration(clockTime.timeZoneOffset*-1);
						////moment = moment.add(offset);
						//myPrintLn(moment.value().toString());
						////var date = Calendar.info(moment, 0);
						//var date = Calendar.utcInfo(moment, 0);
						//myPrintLn(format("$1$-$2$-$3$T$4$:$5$:$6$",
						//				[
						//				date.year,
						//				date.month.format("%02d"),
						//				date.day.format("%02d"),
						//				date.hour.format("%02d"),
						//				date.min.format("%02d"),
						//				date.sec.format("%02d")]
						//			   ));
						loopElapsedSecs = moment.value();
						var loopElapsedMins = Math.floor(Time.now().subtract(moment).value() / 60);
						if (loopElapsedMins > elapsedAlert) {
							loopstatus = loopElapsedMins.toString() + "m";
						}
						//myPrintLn(Time.now().value().toString());
						predictions = [];
						if (numPredictions > 0) {
			            	//myPrintLn(data["loop"]["lastPredicted"]["values"][numPredictions-1].toString());
				            //myPrintLn(data["loop"]["lastPredicted"]["values"][0].toString());
				            predicted = "->" + mmol_or_mgdl_str(data["loop"]["lastPredicted"]["values"][numPredictions-1]);
				            minPredict = data["loop"]["lastPredicted"]["values"][numPredictions-1].toNumber();
				            maxPredict = minPredict;
				            for (var i=0; i < numPredictions; i++) {
				        		var myNum = data["loop"]["lastPredicted"]["values"][i].toNumber();
				        		predictions.add(myNum);
				            	if (myNum < minPredict) {
					        		minPredict = myNum;
				        		}
				            	if (myNum > maxPredict) {
					        		maxPredict = myNum;
				        		}
				            }
			        	}
			            //myPrintLn(minPredict);
			            //myPrintLn(maxPredict);
		            } else {
		            	loopElapsedSecs = 0;
		            	predicted = "";
		            }
	
		       		if (((elapsedMills / 1000.0) < (loopElapsedSecs - 300)) &&
		       			(bg != data["loop"]["lastPredicted"]["values"][0])) {
		       			bg = data["loop"]["lastPredicted"]["values"][0];
		       			delta = "S?";
			        	direction = "";
			        	directionIcon = null;
		       			//myPrintLn(elapsedMills.toString());
		       			//myPrintLn(loopElapsedSecs.toString());
		       			elapsedMills = loopElapsedSecs * 1000.0;
		       			//myPrintLn(elapsedMills.toString());
					} 
/*
	            } else if (data.hasKey("openaps") &&
	                data["openaps"].hasKey("lastLoopMoment") &&
	                (data["openaps"]["lastLoopMoment"] != null)) {
	                // OpenAPS
	            	if (data["openaps"].hasKey("status") &&
		            	data["openaps"]["status"].hasKey("label")) {
		            	//myPrintLn(data["openaps"]["status"]["label"].toString());
	    	        	loopstatus = data["openaps"]["status"]["label"].toString();
	    	        	var statuslen = loopstatus.length();
	    	        	if (statuslen > 7) {
	    	        		statuslen = 7;
		        		}
	    	        	loopstatus = loopstatus.substring(0, statuslen);
		        	} else {
		        		loopstatus = "";
			        }
					var openapsCurBG = 0;
			        if (data["openaps"].hasKey("lastPredBGs") &&
			        	(data["openaps"]["lastPredBGs"] != null) &&
			        	data["openaps"]["lastPredBGs"].hasKey("IOB") &&
			        	data["openaps"]["lastPredBGs"].hasKey("moment")) {
	            		//myPrintLn(data["openaps"]["lastPredBGs"]["moment"].toString());
						var loopTime = data["openaps"]["lastPredBGs"]["moment"].toString();
						var options = { :year => loopTime.substring(0,4).toNumber(),
										:month => loopTime.substring(5,7).toNumber(),
										:day => loopTime.substring(8,10).toNumber(),
										:hour => loopTime.substring(11,13).toNumber(),
										:minute => loopTime.substring(14,16).toNumber(),
										:second => loopTime.substring(17,19).toNumber() };
						var moment = Calendar.moment(options);
						//var clockTime = System.getClockTime();
						//myPrintLn("timezoneoffset=" + clockTime.timeZoneOffset.toString());
						//var offset = new Time.Duration(clockTime.timeZoneOffset*-1);
						////moment = moment.add(offset);
						//myPrintLn(moment.value().toString());
						////var date = Calendar.info(moment, 0);
						//var date = Calendar.utcInfo(moment, 0);
						//myPrintLn(format("$1$-$2$-$3$T$4$:$5$:$6$",
						//				[
						//				date.year,
						//				date.month.format("%02d"),
						//				date.day.format("%02d"),
						//				date.hour.format("%02d"),
						//				date.min.format("%02d"),
						//				date.sec.format("%02d")]
						//			   ));
						loopElapsedSecs = moment.value();
						var loopElapsedMins = Math.floor(Time.now().subtract(moment).value() / 60);
						if (loopElapsedMins > elapsedAlert) {
							loopstatus = loopElapsedMins.toString() + "m";
						}
						//myPrintLn(Time.now().value().toString());
						var numPredictions = data["openaps"]["lastPredBGs"]["IOB"].size();
			        	if (data["openaps"]["lastPredBGs"].hasKey("COB")) {
				        	numPredictions = data["openaps"]["lastPredBGs"]["COB"].size();
			        	}
						predictions = [];
						if (numPredictions > 0) {
			            	//myPrintLn(data["openaps"]["lastPredBGs"]["values"][numPredictions-1].toString());
				            //myPrintLn(data["openaps"]["lastPredBGs"]["values"][0].toString());
				        	if (data["openaps"]["lastPredBGs"].hasKey("COB")) {
					            predicted = "->" + data["openaps"]["lastPredBGs"]["COB"][numPredictions-1].toString();
					            minPredict = data["openaps"]["lastPredBGs"]["COB"][numPredictions-1].toNumber();
					            openapsCurBG = data["openaps"]["lastPredBGs"]["COB"][0];
				        	} else {
					            predicted = "->" + data["openaps"]["lastPredBGs"]["IOB"][numPredictions-1].toString();
					            minPredict = data["openaps"]["lastPredBGs"]["IOB"][numPredictions-1].toNumber();
					            openapsCurBG = data["openaps"]["lastPredBGs"]["IOB"][0];
				            }
				            maxPredict = minPredict;
				            for (var i=0; i < numPredictions; i++) {
				            	var myNum;
					        	if (data["openaps"]["lastPredBGs"].hasKey("COB")) {
					        		myNum = data["openaps"]["lastPredBGs"]["COB"][i].toNumber();
					        	} else {
				        	 		myNum = data["openaps"]["lastPredBGs"]["IOB"][i].toNumber();
				        		}
				        		predictions.add(myNum);
				            	if (myNum < minPredict) {
					        		minPredict = myNum;
				        		}
				            	if (myNum > maxPredict) {
					        		maxPredict = myNum;
				        		}
				            }
			        	}
			            //myPrintLn(minPredict);
			            //myPrintLn(maxPredict);
		            } else {
		            	loopElapsedSecs = 0;
		            	predicted = "";
		            }
	
	            	if (data["openaps"].hasKey("lastEnacted") &&
						data["openaps"]["lastEnacted"].hasKey("COB")) {
			            //myPrintLn(data["openaps"]["lastEnacted"]["COB"].toString());
			            cob = data["openaps"]["lastEnacted"]["COB"].toString() + "g";
		            } else {
		            	cob = "";
		            }
	
					if (data["openaps"].hasKey("lastIOB") &&
						data["openaps"]["lastIOB"].hasKey("iob")) {
			            //myPrintLn(data["openaps"]["lastIOB"]["iob"].toString());
			            iob = data["openaps"]["lastIOB"]["iob"].toString() + "U";
		            	while ((iob.toString().find("0U") != null) &&
		            		   (iob.toString().find("0U") != 0)) {
		            		iob = iob.toString().substring(0, iob.toString().find("0U")) + "U";
		            	}
		            } else {
		            	iob = "";
		            }
	
	            	if (data["openaps"].hasKey("lastEnacted") &&
						data["openaps"]["lastEnacted"].hasKey("rate")) {
			            //myPrintLn(data["basal"]["display"].toString());
		            	basal = data["openaps"]["lastEnacted"]["rate"].toString() + "U";
		            	while ((basal.toString().find("0U") != null) &&
		            		   (basal.toString().find("0U") > 0)) {
		            		basal = basal.toString().substring(0, basal.toString().find("0U")) + "U";
		            	}
		        	} else {
		        		basal = "";
		        	}
	
		       		if (((elapsedMills / 1000.0) < (loopElapsedSecs - 300)) &&
		       			openapsCurBG > 0) {
		       			bg = openapsCurBG;
		       			delta = "S?";
			        	direction = "";
			        	directionIcon = null;
		       			//myPrintLn(elapsedMills.toString());
		       			//myPrintLn(loopElapsedSecs.toString());
		       			elapsedMills = loopElapsedSecs * 1000.0;
		       			//myPrintLn(elapsedMills.toString());
					} 
	            } else {
*/
	            } else if (data.hasKey("pump") &&
	                	   data["pump"].hasKey("openaps")) {
	                // OpenAPS
	                // We have to use pump data instead of openaps to keep memory usage down for some watches (Fenix3, Forerunner 235...)
			    	myPrintLn("in LoopView onReceive openaps");
	                if (data["pump"]["openaps"].hasKey("enacted") &&
	                	data["pump"]["openaps"]["enacted"].hasKey("timestamp") &&
	                	(data["pump"]["openaps"]["enacted"]["timestamp"] != null)) {
		            	//myPrintLn("enacted: " + data["pump"]["openaps"]["enacted"]["timestamp"].toString());
						var loopTime = data["pump"]["openaps"]["enacted"]["timestamp"].toString();
						var options = { :year => loopTime.substring(0,4).toNumber(),
										:month => loopTime.substring(5,7).toNumber(),
										:day => loopTime.substring(8,10).toNumber(),
										:hour => loopTime.substring(11,13).toNumber(),
										:minute => loopTime.substring(14,16).toNumber(),
										:second => loopTime.substring(17,19).toNumber() };
						var moment = Calendar.moment(options);
						//var clockTime = System.getClockTime();
						//myPrintLn("timezoneoffset=" + clockTime.timeZoneOffset.toString());
						//var offset = new Time.Duration(clockTime.timeZoneOffset*-1);
						////moment = moment.add(offset);
						//myPrintLn(moment.value().toString());
						////var date = Calendar.info(moment, 0);
						//var date = Calendar.utcInfo(moment, 0);
						//myPrintLn(format("$1$-$2$-$3$T$4$:$5$:$6$",
						//				[
						//				date.year,
						//				date.month.format("%02d"),
						//				date.day.format("%02d"),
						//				date.hour.format("%02d"),
						//				date.min.format("%02d"),
						//				date.sec.format("%02d")]
						//			   ));
						loopElapsedSecs = moment.value();
						var loopElapsedMins = Math.floor(Time.now().subtract(moment).value() / 60);
						loopstatus = "Enacted";
						if (loopElapsedMins > elapsedAlert) {
							if (loopElapsedMins > (6 * 60)) {
								loopstatus = "STOPPED";
							} else {
								loopstatus = "STOPPED " + loopElapsedMins.toString() + "m";
							}
						} else if (loopElapsedMins > elapsedWarning) {
							loopstatus = loopstatus.substring(0,3) + " " + loopElapsedMins.toString() + "m";
						}
						//myPrintLn("loopElapsed enact: " + loopElapsedMins);
						//myPrintLn(Time.now().value().toString());
					} else {
		            	loopElapsedSecs = 0;
		            	loopstatus = "";
					}

					if (data["pump"]["openaps"].hasKey("suggested") &&
	                	data["pump"]["openaps"]["suggested"].hasKey("timestamp") &&
	                	(data["pump"]["openaps"]["suggested"]["timestamp"] != null)
	                	) {
		            	//myPrintLn("suggested: " + data["pump"]["openaps"]["suggested"]["timestamp"].toString());
						var loopTime = data["pump"]["openaps"]["suggested"]["timestamp"].toString();
						var options = { :year => loopTime.substring(0,4).toNumber(),
										:month => loopTime.substring(5,7).toNumber(),
										:day => loopTime.substring(8,10).toNumber(),
										:hour => loopTime.substring(11,13).toNumber(),
										:minute => loopTime.substring(14,16).toNumber(),
										:second => loopTime.substring(17,19).toNumber() };
						var moment = Calendar.moment(options);
						//var clockTime = System.getClockTime();
						//myPrintLn("timezoneoffset=" + clockTime.timeZoneOffset.toString());
						//var offset = new Time.Duration(clockTime.timeZoneOffset*-1);
						////moment = moment.add(offset);
						//myPrintLn(moment.value().toString());
						////var date = Calendar.info(moment, 0);
						//var date = Calendar.utcInfo(moment, 0);
						//myPrintLn(format("$1$-$2$-$3$T$4$:$5$:$6$",
						//				[
						//				date.year,
						//				date.month.format("%02d"),
						//				date.day.format("%02d"),
						//				date.hour.format("%02d"),
						//				date.min.format("%02d"),
						//				date.sec.format("%02d")]
						//			   ));
						{
							if ((loopstatus.find("STOPPED") == null) &&
							    (loopElapsedSecs == 0) ||
								(loopElapsedSecs < moment.value())) {
								loopElapsedSecs = moment.value();
								loopstatus = "Looping";
								var loopElapsedMins = Math.floor(Time.now().subtract(moment).value() / 60);
								if (loopElapsedMins > elapsedAlert) {
									if (loopElapsedMins > (6 * 60)) {
										loopstatus = "STOPPED";
									} else {
										loopstatus = "STOPPED " + loopElapsedMins.toString() + "m";
									}
								} else if (loopElapsedMins > elapsedWarning) {
									loopstatus = loopstatus.substring(0,3) + " " + loopElapsedMins.toString() + "m";
								}
								//myPrintLn("loopElapsed suggest: " + loopElapsedMins);
							}
						}
						//myPrintLn(Time.now().value().toString());
					}

					var openapsCurBG = 0;
					var predKey = "suggested";
			        if ((loopstatus.find("Ena") == 0) &&
			            data["pump"]["openaps"]["enacted"].hasKey("predBGs") &&
			        	(data["pump"]["openaps"]["enacted"]["predBGs"] != null) &&
			        	data["pump"]["openaps"]["enacted"]["predBGs"].hasKey("IOB")) {
			        	predKey = "enacted";
					}
					//myPrintLn("using predKey=" + predKey);
			        if (data["pump"]["openaps"].hasKey(predKey) &&
			            data["pump"]["openaps"][predKey].hasKey("predBGs") &&
			        	(data["pump"]["openaps"][predKey]["predBGs"] != null) &&
			        	data["pump"]["openaps"][predKey]["predBGs"].hasKey("IOB")) {
						var numPredictions = data["pump"]["openaps"][predKey]["predBGs"]["IOB"].size();
			        	if (data["pump"]["openaps"][predKey]["predBGs"].hasKey("COB")) {
				        	numPredictions = data["pump"]["openaps"][predKey]["predBGs"]["COB"].size();
			        	}
						predictions = [];
						if (numPredictions > 0) {
				        	if (data["pump"]["openaps"][predKey]["predBGs"].hasKey("COB")) {
					            predicted = "->" + mmol_or_mgdl_str(data["pump"]["openaps"][predKey]["predBGs"]["COB"][numPredictions-1]);
					            minPredict = data["pump"]["openaps"][predKey]["predBGs"]["COB"][numPredictions-1].toFloat();
					            openapsCurBG = data["pump"]["openaps"][predKey]["predBGs"]["COB"][0].toFloat();
				        	} else {
					            predicted = "->" + mmol_or_mgdl_str(data["pump"]["openaps"][predKey]["predBGs"]["IOB"][numPredictions-1]);
					            minPredict = data["pump"]["openaps"][predKey]["predBGs"]["IOB"][numPredictions-1].toFloat();
					            openapsCurBG = data["pump"]["openaps"][predKey]["predBGs"]["IOB"][0].toFloat();
				            }
				            maxPredict = minPredict;
				            if (numPredictions > 60) {
				            	// limit the # of predictions to 5 hours=300minutes/5=60 to avoid memory limit on some watches...
				            	numPredictions = 60;
				            }
				            for (var i=0; i < numPredictions; i++) {
				            	var myNum;
					        	if (data["pump"]["openaps"][predKey]["predBGs"].hasKey("COB")) {
					        		myNum = data["pump"]["openaps"][predKey]["predBGs"]["COB"][i].toFloat();
					        	} else {
				        	 		myNum = data["pump"]["openaps"][predKey]["predBGs"]["IOB"][i].toFloat();
				        		}
				        		predictions.add(myNum);
				            	if (myNum < minPredict) {
					        		minPredict = myNum;
				        		}
				            	if (myNum > maxPredict) {
					        		maxPredict = myNum;
				        		}
				            }
			        	}
			            //myPrintLn(minPredict);
			            //myPrintLn(maxPredict);
		            } else {
		            	predicted = "";
		            }
	
			        if (data["pump"]["openaps"].hasKey(predKey)) {
		            	if (data["pump"]["openaps"][predKey].hasKey("COB")) {
				            cob = data["pump"]["openaps"][predKey]["COB"].toString() + "g";
			            } else {
			            	cob = "";
			            }
			        } else {
			        	cob = "";
			        }

			        if (data["pump"]["openaps"].hasKey("iob")) {
		            	if ((data["pump"]["openaps"]["iob"] != null) &&
		            		data["pump"]["openaps"]["iob"].hasKey("iob")) {
				            iob = data["pump"]["openaps"]["iob"]["iob"].toString() + "U";
			            	while ((iob.toString().find("0U") != null) &&
			            		   (iob.toString().find("0U") != 0)) {
			            		iob = iob.toString().substring(0, iob.toString().find("0U")) + "U";
			            	}
			            } else {
			            	iob = "";
			            }
			        } else {
			        	iob = "";
			        }
	
	            	if (data["pump"]["openaps"].hasKey(predKey) &&
						data["pump"]["openaps"][predKey].hasKey("rate") &&
						data["pump"]["openaps"][predKey]["rate"] != null) {
		            	basal = "T" + data["pump"]["openaps"][predKey]["rate"].toString() + "U";
	            	} else if (basal.equals("") &&
	            			   data["pump"]["openaps"].hasKey("enacted") &&
							   data["pump"]["openaps"]["enacted"].hasKey("rate") &&
							   data["pump"]["openaps"]["enacted"]["rate"] != null) {
						// grab an older enacted basal if present and we don't have one already
						// sometimes this can be out of date (possibly due to multiple rigs enacting...)
				        basal = "T" + data["pump"]["openaps"]["enacted"]["rate"].toString() + "U";
		            } else {
		        		// hang onto last value - appears to be a NS bug where rate is not sent always
		        		// basal = "";
		        	}
	            	while ((basal.toString().find("0U") != null) &&
	            		   (basal.toString().find("0U") > 1)) {
	            		basal = basal.toString().substring(0, basal.toString().find("0U")) + "U";
	            	}
	/* This isn't useful on OpenAPS as BG comes from NS regardless, so share or OpenAPS already update it.
		       		if (((elapsedMills / 1000.0) < (loopElapsedSecs - 300)) &&
		       			openapsCurBG > 0) {
		       			bg = openapsCurBG;
		       			delta = "S?";
			        	direction = "";
			        	directionIcon = null;
		       			//myPrintLn(elapsedMills.toString());
		       			//myPrintLn(loopElapsedSecs.toString());
		       			elapsedMills = loopElapsedSecs * 1000.0;
		       			//myPrintLn(elapsedMills.toString());
					} 
*/
			    	myPrintLn("out LoopView onReceive openaps");
	            } else {
	        		loopstatus = "";
	            	loopElapsedSecs = 0;
	            	predicted = "";
	            	cob = "";
	            }
	
	            //myPrintLn(Time.now().toString());
	            if (data.hasKey("pump") &&
	            	data["pump"].hasKey("data")) {
	            	if (data["pump"]["data"].hasKey("battery") &&
	            		(data["pump"]["data"]["battery"] != null) &&
	            		data["pump"]["data"]["battery"].hasKey("value") &&
	            		data["pump"]["data"]["battery"].hasKey("display")) {
			            //myPrintLn(data["pump"]["data"]["battery"]["value"].toString());
			            pumpbat = data["pump"]["data"]["battery"]["value"];
			            pumpbatdisplay = data["pump"]["data"]["battery"]["display"].toString();
		            } else {
		            	pumpbat = -1;
		            	pumpbatdisplay = "";
		            }
	            	//if (data["pump"]["data"].hasKey("clock") &&
	            	//	(data["pump"]["data"]["clock"] != null) &&
	            	//	data["pump"]["data"]["clock"].hasKey("display")) {
			        //    //myPrintLn(data["pump"]["data"]["clock"]["display"].toString());
			        //    pumpelapsed = data["pump"]["data"]["clock"]["display"].toString();
		            //} else {
	        	    //	pumpelapsed = "";
		            //}
	            	if (data["pump"]["data"].hasKey("reservoir") &&
	            		(data["pump"]["data"]["reservoir"] != null) &&
	            		data["pump"]["data"]["reservoir"].hasKey("value")) {
	                    //myPrintLn(data["pump"]["data"]["reservoir"]["value"].toString());
	        		    reservoir = data["pump"]["data"]["reservoir"]["value"];
		            } else {
		            	reservoir = -1;
		            }
	            } else {
	            	pumpbat = -1;
	            	pumpbatdisplay = "";
	            	//pumpelapsed = "";
	            	reservoir = -1;
	            }
	            if (data.hasKey("pump") &&
	            	data["pump"].hasKey("uploader") &&
	            	(data["pump"]["uploader"] != null) &&
	            	data["pump"]["uploader"].hasKey("battery")) {
		            //myPrintLn(data["pump"]["uploader"]["battery"].toString());
		            phonebat = data["pump"]["uploader"]["battery"];
	            } else {
	            	phonebat = -1;
	            }
	        } catch (ex) {
			    myPrintLn("exception processing request");
			    myPrintLn(ex.getErrorMessage);
				ex.printStackTrace();
				loopstatus = "err2" + ex.getErrorMessage;
	        }
		} else {
			myPrintLn("onReceive error");
			myPrintLn("response: " + responseCode.toString());
		}
		requestComplete = true;
        Ui.requestUpdate();
        processAlerts();
		myPrintLn("out onReceive()");
	}
	
    static var savedMin = -1;

	function setupDrawColor(dc, alerted, warned) {
		var alertFG = Gfx.COLOR_RED;
		var alertBG = Gfx.COLOR_WHITE;
		var warnFG = Gfx.COLOR_YELLOW;
		var warnBG = Gfx.COLOR_BLACK;
		var normalFG = Gfx.COLOR_WHITE;
		var normalBG = Gfx.COLOR_TRANSPARENT;

		if (alerted) {
	        dc.setColor(alertFG, alertBG);
		} else {
			if (warned) {
		        dc.setColor(warnFG, warnBG);
			} else {
		        dc.setColor(normalFG, normalBG);
	        }
		}
	}
	
    // Handle the update event
    function onUpdate(dc) {
        var width;
        var height;
        var screenWidth = dc.getWidth();
        var clockTime = Sys.getClockTime();
        var hourHand;
        var minuteHand;
        var secondHand;
        var secondTail;
		var stats = Sys.getSystemStats();

        width = dc.getWidth();
        height = dc.getHeight();
		//myPrintLn("W: " + width.toString() + ", H: " + height.toString());

        var now = Time.now();
        var info = Calendar.info(now, Time.FORMAT_LONG);

		var is24Hour = Sys.getDeviceSettings().is24Hour;
		var myHour = is24Hour ? clockTime.hour :
							    (clockTime.hour % 12) ? clockTime.hour % 12 : 12;
		var timeOffset = 0;
		if (myHour >= 20) {
			timeOffset = 5;
		}
        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);
        var hourStr = Lang.format("$1$", [myHour]);
        var minStr = Lang.format("$1$", [clockTime.min < 10 ? "0" + clockTime.min.toString() : clockTime.min]);
        var secStr = Lang.format("$1$", [clockTime.sec < 10 ? "0" + clockTime.sec.toString() : clockTime.sec]);

        // Clear the screen
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_WHITE);
        dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

        // Draw the numbers
/*
        dc.drawText((width / 2), 2, font, "12", Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(width - 2, (height / 2) - 15, font, "3", Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(width / 2, height - 30, font, "6", Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(2, (height / 2) - 15, font, "9", Gfx.TEXT_JUSTIFY_LEFT);
*/
		// bg, direction, delta, elapsed
		// loopstatus, predicted
		// pumpbat, pumpelapsed, reservoir, phonebat;
        var myMoment = new Time.Moment(elapsedMills / 1000);
        //myPrintLn(Time.now().value().toString());
        //myPrintLn(myMoment.value().toString());
        //myPrintLn(Time.now().subtract(myMoment).value().toString());
		var elapsedMinutes = Math.floor(Time.now().subtract(myMoment).value() / 60);
        var elapsed = elapsedMinutes.format("%d") + "m";
        if ((elapsedMinutes > 9999) || (elapsedMinutes < -999)) {
        	elapsed = "";
        }
	
		var lineY, edgeX, edgeY, separationY;
		var showBatteryLine, showDateLine;
		showBatteryLine = true;
		showDateLine = true;
		//myPrintLn("shape: " + screenShape.toString());
        if (Sys.SCREEN_SHAPE_RECTANGLE != screenShape) {
        	if (height > 220) {
	        	// assumes (fenix5*/935/approach-s60/d2-charlie/vivoactive3): W: 240, H: 240
				lineY = [ 12,    // BG
						  38,    // direction,...
						  63,    // loop...
						  88,    // battery...
						  113,   // basal...
						  138,   // OB...
						  163,   // date
						  196 ]; // time
				edgeX = 48; //50;
				edgeY = 34; //36;
				separationY = 17;
        	} else if (height > 200) {
	        	// assumes (fenix3/bravo/etc): W: 218, H: 218
				lineY = [ 12,    // BG
						  35,    // direction,...
						  57,    // loop...
						  79,    // battery...
						  101,   // basal...
						  123,   // OB...
						  145,   // date
						  174 ]; // time
				edgeX = 45;
				edgeY = 34;
				separationY = 15;
			} else {
	        	// assumes (forerunner 230/235/630/735xt/etc) W: 215, H: 180
				lineY = [ 2,     // BG
						  27,    // direction,...
						  47,    // loop...
						  67,    // battery...
						  87,    // basal...
						  107,   // OB...
						  127,   // date
						  151 ]; // time
				edgeX = 42;
				edgeY = 19;
				separationY = 15;
			}
	    } else {
	    	if (height > 200) {
		    	// assumes (vivoactiveHR/etc) W: 148, H: 205
				lineY = [ 2,     // BG
						  32,    // direction,...
						  55,    // loop...
						  78,    // battery...
						  101,   // basal...
						  124,   // OB...
						  147,   // date
						  175 ]; // time
				edgeX = 4;
				edgeY = 20;
				separationY = 15;
			} else {
		    	// assumes (vivoactive/920XT) W: 205, H: 148
				lineY = [ 2,     // BG
						  30,    // direction,...
						  51,    // loop...
						  0,     // N/A (battery...)
						  72,    // basal...
						  93,    // OB... or batteries if low
						  0,     // N/A (date)
						  120 ]; // time
				edgeX = 5;
				edgeY = 17;
				separationY = 15;
				showBatteryLine = false;
				showDateLine = false;
			}
	    }

        // Draw prediction graph in the background
        dc.setColor(Gfx.COLOR_DK_BLUE, Gfx.COLOR_DK_BLUE);
        for (var i=0; (i+1) < predictions.size(); i++) {
        	var X1 = width * i / (predictions.size() - 1);
        	var X2 = width * (i+1) / (predictions.size() - 1);
        	// predictions are in mgDL, top of screen=500, bottom=0;
        	var Y1 = height * (1.0 - (predictions[i] / 500.0));
        	var Y2 = height * (1.0 - (predictions[i+1] / 500.0));
        	dc.fillPolygon([[X1, 0], [X2, 0], [X2, Y2], [X1, Y1]]);
        	//myPrintLn("drawing rect: " + X1 + ", " + Y1 + " to " + X2 + ", " + Y2);
    	}

		// Draw all info
		setupDrawColor(dc, bgAlerted, bgWarned);
        if (!isMGDL) {
        	var bgInt = bg.toNumber();
        	var bgFrac = ((bg - bgInt) * 10).toNumber();
	        dc.drawText(width / 2 - 5, lineY[0]/*-Gfx.getFontDescent(font)*/, font, bgInt.toString(), Gfx.TEXT_JUSTIFY_RIGHT);
    	    dc.drawText(width / 2 + 5, lineY[0]/*-Gfx.getFontDescent(font)*/, font, bgFrac.toString(), Gfx.TEXT_JUSTIFY_LEFT);
	        dc.fillCircle(width / 2 - 0, lineY[0] + 20, 4);
        } else {
			dc.drawText((width / 2), lineY[0]/*-Gfx.getFontDescent(font)*/, font, bg.toString(), Gfx.TEXT_JUSTIFY_CENTER);
		}
		setupDrawColor(dc, predictAlerted, predictWarned);
        if (minPredict != null) {
			dc.drawText(edgeX, lineY[0], Gfx.FONT_XTINY, "  " + mmol_or_mgdl_str(minPredict).toString(), Gfx.TEXT_JUSTIFY_LEFT);
		}
		if (maxPredict != null) {
			dc.drawText(width - edgeX, lineY[0], Gfx.FONT_XTINY, mmol_or_mgdl_str(maxPredict).toString() + "  ", Gfx.TEXT_JUSTIFY_RIGHT);
		}
		setupDrawColor(dc, elapsedAlerted, elapsedWarned);
        dc.drawText(width / 2 - 20, lineY[1], Gfx.FONT_MEDIUM, delta, Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(width / 2 + 20, lineY[1], Gfx.FONT_MEDIUM, elapsed, Gfx.TEXT_JUSTIFY_LEFT);
        if (null != directionIcon) {
            dc.drawBitmap(width / 2 - 12, lineY[1] + 3, directionIcon);
        }
		setupDrawColor(dc, loopstatusAlerted, loopstatusWarned);
        dc.drawText(width / 2, lineY[2], Gfx.FONT_MEDIUM, loopstatus + " " + predicted, Gfx.TEXT_JUSTIFY_CENTER);
		setupDrawColor(dc, phonebatAlerted || pumpbatAlerted, phonebatWarned || pumpbatWarned);
        if (showBatteryLine && ((phonebat > -1) || (pumpbat > -1))) {
	        dc.drawText(width / 2, lineY[3], Gfx.FONT_MEDIUM, "up:" + phonebat.toString() + "% pu:" + pumpbatdisplay.toString(), Gfx.TEXT_JUSTIFY_CENTER);
        }
		setupDrawColor(dc, reservoirAlerted, reservoirWarned);
		//myPrintLn("basal: " + basal + ", rs: " + reservoir + ", length: " + basal.length());
        if (basal.length() && (reservoir != -1)) {
	        dc.drawText(width / 2, lineY[4], Gfx.FONT_MEDIUM, basal + " rs:" + reservoir.toNumber().toString() + "U", Gfx.TEXT_JUSTIFY_CENTER);
	    } else if (basal.length() > 0) {
	        dc.drawText(width / 2, lineY[4], Gfx.FONT_MEDIUM, basal, Gfx.TEXT_JUSTIFY_CENTER);
	    } else if (reservoir != -1) {
	        dc.drawText(width / 2, lineY[4], Gfx.FONT_MEDIUM, " rs:" + reservoir.toNumber().toString() + "U", Gfx.TEXT_JUSTIFY_CENTER);
	    }
	        
		setupDrawColor(dc, pumpbatAlerted || phonebatAlerted, phonebatWarned || pumpbatWarned);
        if ((pumpbatAlerted || phonebatAlerted) && !showBatteryLine) {
	        dc.drawText(width / 2, lineY[5], Gfx.FONT_MEDIUM, "up:" + phonebat.toString() + "% pu:" + pumpbatdisplay.toString(), Gfx.TEXT_JUSTIFY_CENTER);
        } else if ((iob.length()) || (cob.length())) {
			setupDrawColor(dc, false, false);
	        dc.drawText(width / 2, lineY[5], Gfx.FONT_MEDIUM, "ob: " + iob + " " + cob, Gfx.TEXT_JUSTIFY_CENTER);
		}

        // Draw the date
		setupDrawColor(dc, false, false);
        if (showDateLine) {
        	dc.drawText(width / 2, lineY[6], Gfx.FONT_MEDIUM, dateStr, Gfx.TEXT_JUSTIFY_CENTER);
    	}
    	if (showSeconds) {
			setupDrawColor(dc, stats.battery < 25, stats.battery < 50);
	        dc.drawText(width - edgeX, height - edgeY, Gfx.FONT_XTINY, secStr + " ", Gfx.TEXT_JUSTIFY_RIGHT);
			setupDrawColor(dc, false, false);
    	} else if (stats.battery < 50.0) {
	        dc.drawText(width - edgeX, height - edgeY, Gfx.FONT_XTINY, stats.battery.toNumber().toString()+"%", Gfx.TEXT_JUSTIFY_RIGHT);
        }
        if (testno > 0) {
            dc.drawText(width - edgeX, height - edgeY - separationY, Gfx.FONT_XTINY, testno.toString(), Gfx.TEXT_JUSTIFY_RIGHT);
        } else {
	        if (Sys.getDeviceSettings().notificationCount > 0) {
		        dc.drawText(width - edgeX, height - edgeY - separationY, Gfx.FONT_XTINY, Sys.getDeviceSettings().notificationCount.toString(), Gfx.TEXT_JUSTIFY_RIGHT);
	        }
        }
        // Draw the do-not-disturb icon
        if (null != disconnIcon && !Sys.getDeviceSettings().phoneConnected) {
            dc.drawBitmap( edgeX - 4, height - edgeY - 3, disconnIcon);
        } else {
	        if (null != dndIcon && ((silenceGesture && silenced) || ((Sys.getDeviceSettings() has :doNotDisturb) && (respectDND && Sys.getDeviceSettings().doNotDisturb)))) {
	            dc.drawBitmap( edgeX - 4, height - edgeY - 3, dndIcon);
	        }
        }
        // Draw the digital time
        dc.drawText(width / 2 - 10 + timeOffset, lineY[7]/*-Gfx.getFontDescent(font)*/, font, hourStr, Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(width / 2 + 0 + timeOffset, lineY[7]/*-Gfx.getFontDescent(font)*/, font, minStr, Gfx.TEXT_JUSTIFY_LEFT);
        dc.fillCircle(width / 2 - 5 + timeOffset, lineY[7] + 7, 4);
        dc.fillCircle(width / 2 - 5 + timeOffset, lineY[7] + 20, 4);

/*
        // Draw the hash marks
        drawHashMarks(dc);

        // Draw the do-not-disturb icon
        if (null != dndIcon && Sys.getDeviceSettings().doNotDisturb) {
            dc.drawBitmap( width * 0.75, height / 2 - 15, dndIcon);
        }

        // Draw the hour. Convert it to minutes and compute the angle.
        hourHand = (((clockTime.hour % 12) * 60) + clockTime.min);
        hourHand = hourHand / (12 * 60.0);
        hourHand = hourHand * Math.PI * 2;
        drawHand(dc, hourHand, 40, 3);

        // Draw the minute
        minuteHand = (clockTime.min / 60.0) * Math.PI * 2;
        drawHand(dc, minuteHand, 70, 2);

        // Draw the second
        if (isAwake) {
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
            secondHand = (clockTime.sec / 60.0) * Math.PI * 2;
            secondTail = secondHand - Math.PI;
            drawHand(dc, secondHand, 60, 2);
            drawHand(dc, secondTail, 20, 2);
        }

        // Draw the arbor
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_BLACK);
        dc.fillCircle(width / 2, height / 2, 5);
        dc.setColor(Gfx.COLOR_BLACK,Gfx.COLOR_BLACK);
        dc.drawCircle(width / 2, height / 2, 5);
*/
        
       if (((testno > 0) && reload) || ((clockTime.min != savedMin) && requestComplete && elapsedMinutes >= (5+elapsedOffset))) {
//	   if (requestComplete) { // for testing VAHR firmware bug
        	try {
	        	myPrintLn("minute: " + clockTime.min.toString() + ", requestComplete: " + requestComplete + ", elapsedMinutes: " + elapsedMinutes + ", elapsedOffset: " + elapsedOffset);
				var url = nsurl;
				if (url) {
					if (dataMode == dataModeOpenAPS) {
						// limit the amount requested since the watches are very memory sensitive here...
						url = url + "/api/v2/properties/bgnow,pump,delta";
					} else if (dataMode == dataModeLoop) {
						// Loop:
						url = url + "/api/v2/properties/basal,bgnow,iob,cob,loop,pump,delta";
					} else {
						// BG-only:
						url = url + "/api/v2/properties/bgnow,rawbg,delta";
					}
					if (testno > 0) {
						testno++;
						if (testno > maxtestno) {
							testno = 1;
						}
//						url = "https://tynbendad.github.io/pumptest/api/v2/properties/test" + testno + ".json";
						url = "https://tynbendad.github.io/pumptest/api/v2/properties/vahr-crash.json";
//						url = "http://192.168.1.106:8080/test1.json";
					}
					myPrintLn("url: " + url.toString());
		        	requestComplete = false;
		        	Communications.makeWebRequest(url, {"format" => "json"}, {}, method(:onReceive));
		        	reload = false;
		//            {
		//                "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED
		//            },
		        }
	        } catch (ex) {
			    myPrintLn("exception making web request");
			    myPrintLn(ex.getErrorMessage);
				ex.printStackTrace();
				loopstatus = "err1" + ex.getErrorMessage;
	        }
	        savedMin = clockTime.min;
        }
    }

	function updateView() {
    	//myPrintLn("in LoopView updateView");
		Ui.requestUpdate();
    	//myPrintLn("out LoopView updateView");
	}

    function onEnterSleep() {
        isAwake = false;
        Ui.requestUpdate();
    }

    function onExitSleep() {
        isAwake = true;
    }


    var selectedIndex = 0;
    // Take a tap coordinate and correspond it to one of three sections
    function setIndexFromYVal(yval) {
        var screenHeight = Sys.getDeviceSettings().screenHeight;
        //selectedIndex = (yval / (screenHeight / 3)).toNumber();
    }

    // Decrement the currently selected option index
    function incIndex() {
/*
        if (null != selectedIndex) {
            selectedIndex += 1;
            if (2 < selectedIndex) {
                selectedIndex = 0;
            }
        }
*/
		selectedIndex = 0;
        action();
    }

    // Decrement the currently selected option index
    function decIndex() {
/*
        if (null != selectedIndex) {
            selectedIndex -= 1;
            if (0 > selectedIndex) {
                selectedIndex = 2;
            }
        }
*/
		selectedIndex = 1;
        action();
    }

    // Process the current attention action
    function action() {
    	myPrintLn("in LoopView action, selectedIndex=" + selectedIndex);
        if (0 == selectedIndex) {
        	silenced = false;
        } else {
        	silenced = true;
    	}
    	reload = true;
    	myPrintLn("out LoopView action");
    }

}
