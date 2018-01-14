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
 
using Toybox.Application as App;

class CGMLoop extends App.AppBase
{
	var myView;
	var myDelegate;
	var debugNoSettings = false;	// useful for build-to-USB device deployment, set to false when releasing to store

	function myPrintLn(x) {
		//System.println(x);
	}

    function initialize() {
    	myPrintLn("in initialize");
        AppBase.initialize();
    	myPrintLn("out initialize");
    }

    function onStart(state) {
    }

    function onStop(state) {
    }
    
    function onSettingsChanged() {
    	myPrintLn("in onSettingsChanged");
    	myView.updateSettings();
    	myView.updateView();
    	myPrintLn("out onSettingsChanged");
    }

    function getInitialView() {
    	myPrintLn("in getInitialView");
    	myView = new CGMLoopView();
        myDelegate = new CGMLoopDelegate();
    	myPrintLn("out getInitialView");
        return [ myView, myDelegate ];
    }

    function getGoalView(goal){
    	myPrintLn("in/out getInitialView");
        return [new CGMLoopGoalView(goal)];
    }
}
