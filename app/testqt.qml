/*
 * Copyright (C) 2016 The Qt Company Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *	  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import QtQuick 2.6
import QtQuick.Layouts 1.1
import QtQuick.Controls 2.0
import QtWebSockets 1.0
import QtLocation 5.9
import QtPositioning 5.6
ApplicationWindow {
	id: root
	visible: true
	width: 1080
	height: 1488
	title: qsTr("TestQt")

    property real car_position_lat: 36.131516     // Las Vegas Convention Center
    property real car_position_lon: -115.151507
    property real car_direction: 135    //SouthEast
    property bool st_heading_up: false
    property real default_zoom_level : 18


	Map{
		id: map
        property int pathcounter : 0
        property int segmentcounter : 0
        property int waypoint_count: -1
		property int lastX : -1
		property int lastY : -1
		property int pressX : -1
		property int pressY : -1
		property int jitterThreshold : 30
        property variant currentpostion : QtPositioning.coordinate(car_position_lat, car_position_lon)
        property variant demoguidance_position : currentpostion

        width: 1080
		height: 1488
		plugin: Plugin {
			name: "mapbox"
			PluginParameter { name: "mapbox.access_token";
			value: "pk.eyJ1IjoiYWlzaW53ZWkiLCJhIjoiY2pqNWg2cG81MGJoazNxcWhldGZzaDEwYyJ9.imkG45PQUKpgJdhO2OeADQ" }
		}
        center: currentpostion
        zoomLevel: default_zoom_level
        bearing: 0  //north up

		GeocodeModel {
			id: geocodeModel
			plugin: map.plugin
			onStatusChanged: {
				if ((status == GeocodeModel.Ready) || (status == GeocodeModel.Error))
					map.geocodeFinished()
			}
			onLocationsChanged:
			{
				if (count == 1) {
					map.center.latitude = get(0).coordinate.latitude
					map.center.longitude = get(0).coordinate.longitude
				}
			}
            //coordinate: poiTheQtComapny.coordinate
            //anchorPoint: Qt.point(-poiTheQtComapny.sourceItem.width * 0.5,poiTheQtComapny.sourceItem.height * 1.5)
		}
		MapItemView {
			model: geocodeModel
			delegate: pointDelegate
		}
		Component {
			id: pointDelegate

			MapCircle {
				id: point
				radius: 1000
				color: "#46a2da"
				border.color: "#190a33"
				border.width: 2
				smooth: true
				opacity: 0.25
				center: locationData.coordinate
			}
		}

		function geocode(fromAddress)
		{
			// send the geocode request
			geocodeModel.query = fromAddress
			geocodeModel.update()
		}
		
        MapQuickItem {
            id: poi
            sourceItem: Rectangle { width: 14; height: 14; color: "#e41e25"; border.width: 2; border.color: "white"; smooth: true; radius: 7 }
            coordinate {
                latitude: 36.131516
                longitude: -115.151507
            }
            opacity: 1.0
            anchorPoint: Qt.point(sourceItem.width/2, sourceItem.height/2)
        }
        MapQuickItem {
            sourceItem: Text{
                text: "Convention Center"
                color:"#242424"
                font.bold: true
                styleColor: "#ECECEC"
                style: Text.Outline
            }
            coordinate: poi.coordinate
            anchorPoint: Qt.point(-poi.sourceItem.width * 0.5, poi.sourceItem.height * 1.5)
        }
        MapQuickItem {
            id: car_position_mapitem
            sourceItem: Image {
                id: car_position_mapitem_image
                width: 16
                height: 16
                source: "images/240px-Red_Arrow_Up.svg.png"

                transform: Rotation {
                    id: car_position_mapitem_image_rotate
                    origin.x: car_position_mapitem_image.width/2
                    origin.y: car_position_mapitem_image.height/2
                    angle: car_direction
                }
            }
            anchorPoint: Qt.point(car_position_mapitem_image.width/2, car_position_mapitem_image.height/2)
            coordinate: map.demoguidance_position


            states: [
                State {
                    name: "HeadingUp"
                    PropertyChanges { target: car_position_mapitem_image_rotate; angle: 0 }
                },
                State {
                    name: "NorthUp"
                    PropertyChanges { target: car_position_mapitem_image_rotate; angle: root.car_direction }
                }
            ]
            transitions: Transition {
                NumberAnimation { properties: "angle"; easing.type: Easing.InOutQuad }
            }
        }

        MapQuickItem {
            id: icon_destination
            sourceItem: Image {
                id: icon_destination_image
                width: 16
                height: 16
                source: "images/240px-Red_Arrow_Up.svg.png"
            }
        }

		RouteModel {
			id: routeModel
			plugin : map.plugin
			query:  RouteQuery {
				id: routeQuery
			}
			onStatusChanged: {
				if (status == RouteModel.Ready) {
					switch (count) {
					case 0:
						// technically not an error
					//	map.routeError()
						break
					case 1:
						map.pathcounter = 0
						map.segmentcounter = 0
						console.log("1 route found")
						console.log("path: ", get(0).path.length, "segment: ", get(0).segments.length)
						for(var i = 0; i < get(0).path.length; i++){
							console.log("", get(0).path[i])
						}
						console.log("1st instruction: ", get(0).segments[map.segmentcounter].maneuver.instructionText)
						break
					}
				} else if (status == RouteModel.Error) {
				//	map.routeError()
				}
			}
		}
		
		Component {
			id: routeDelegate

			MapRoute {
				id: route
				route: routeData
				line.color: "#4658da"
				line.width: 10
				smooth: true
				opacity: 0.8
			}
		}
		
		MapItemView {
			model: routeModel
			delegate: routeDelegate
		}

        function addDestination(coord){
            if( waypoint_count < 0 ){
                initDestination()
            }

            if(waypoint_count < 9){
                routeQuery.addWaypoint(coord)
                waypoint_count += 1

                btn_guidance.sts_guide = 1
                btn_guidance.state = "Routing"

                routeModel.update()
                icon_destination.coordinate = coord
            }
        }

        function initDestination(){
            routeModel.reset();
            console.log("initWaypoint")
            routeQuery.clearWaypoints();
            routeQuery.addWaypoint(currentpostion)
            routeQuery.travelModes = RouteQuery.CarTravel
            routeQuery.routeOptimizations = RouteQuery.FastestRoute
            for (var i=0; i<9; i++) {
                routeQuery.setFeatureWeight(i, 0)
            }
            waypoint_count = 0
            pathcounter = 0
            segmentcounter = 0
            routeModel.update();

            // update car_position_mapitem
            car_position_mapitem.coordinate = currentpostion

            // TODO:update car_position_mapitem angle


            // update map.center
            map.center = currentpostion
        }

		function calculateMarkerRoute()
		{
            var startCoordinate = QtPositioning.coordinate(car_position_lat, car_position_lon)

			console.log("calculateMarkerRoute")
			routeQuery.clearWaypoints();
            routeQuery.addWaypoint(startCoordinate)
            routeQuery.addWaypoint(mouseArea.lastCoordinate)
			routeQuery.travelModes = RouteQuery.CarTravel
			routeQuery.routeOptimizations = RouteQuery.FastestRoute
			for (var i=0; i<9; i++) {
				routeQuery.setFeatureWeight(i, 0)
			}
			routeModel.update();
		}

        // Calculate direction from latitude and longitude between two points
        function calculateDirection(lat1, lon1, lat2, lon2) {
            var y1 = lat1 * Math.PI / 180;
            var y2 = lat2 * Math.PI / 180;
            var x1 = lon1 * Math.PI / 180;
            var x2 = lon2 * Math.PI / 180;
            var Y  = Math.cos(x2) * Math.sin(y2 - y1);
            var X  = Math.cos(x1) * Math.sin(x2) - Math.sin(x1) * Math.cos(x2) * Math.cos(y2 - y1);
            var directionEast = 180 * Math.atan2(Y,X) / Math.PI;
            if (directionEast < 0) {
              directionEast = directionEast + 360;
            }
            var directionNorth = (directionEast + 90) % 360;
            return directionNorth;
        }

        // Calculate distance from latitude and longitude between two points
        function calculateDistance(lat1, lon1, lat2, lon2)
        {
            var y1 = lat1 * Math.PI / 180;
            var y2 = lat2 * Math.PI / 180;
            var x1 = lon1 * Math.PI / 180;
            var x2 = lon2 * Math.PI / 180;
            var A = 6378140;
            var B = 6356755;
            var F = (A - B) / A;

            var P1 = Math.atan((B / A) * Math.tan(lat1));
            var P2 = Math.atan((B / A) * Math.tan(lat2));
            var X = Math.acos(Math.sin(P1) * Math.sin(P2) + Math.cos(P1) * Math.cos(P2) * Math.cos(lon1 - lon2));
            var L = (F / 8) * ((Math.sin(X) - X) * Math.pow((Math.sin(P1) + Math.sin(P2)), 2) / Math.pow(Math.cos(X / 2), 2) - (Math.sin(X) - X) * Math.pow(Math.sin(P1) - Math.sin(P2), 2) / Math.pow(Math.sin(X), 2));

            var distance = A * (X + L);
            return Math.round(distance);
        }

        // Setting the next car position from the direction and demonstration mileage
        function setNextCoordinate(curlat,curlon,direction,distance)
        {
            var lat_distance = distance * Math.cos(direction * Math.PI / 180)
            var lat_per_meter = 360 / (2 * Math.PI * 6378140)
            var addlat = lat_distance * lat_per_meter
            var lon_distance = distance * Math.sin(direction * Math.PI / 180)
            var lon_per_meter = 360 / (2 * Math.PI * (6378140 * Math.cos(addlat * Math.PI / 180)))
            var addlon = lon_distance * lon_per_meter
            map.demoguidance_position = QtPositioning.coordinate(curlat+addlat, curlon+addlon);
        }

		MouseArea {
			id: mouseArea
			property variant lastCoordinate
			anchors.fill: parent
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			
			onPressed : {
				map.lastX = mouse.x
				map.lastY = mouse.y
				map.pressX = mouse.x
				map.pressY = mouse.y
				lastCoordinate = map.toCoordinate(Qt.point(mouse.x, mouse.y))
			}
			
			onPositionChanged: {
                if (mouse.button === Qt.LeftButton) {
					map.lastX = mouse.x
					map.lastY = mouse.y
				}
			}
			
			onPressAndHold:{
				if (Math.abs(map.pressX - mouse.x ) < map.jitterThreshold
						&& Math.abs(map.pressY - mouse.y ) < map.jitterThreshold) {
                    map.addDestination(lastCoordinate)
				}
			}
		}
		
		function updatePositon()
		{
			console.log("updatePositon")
            if(pathcounter <= routeModel.get(0).path.length - 1){
                console.log("path: ", pathcounter, "/", routeModel.get(0).path.length - 1, "", routeModel.get(0).path[pathcounter])

                // calculate distance
                var next_distance = calculateDistance(map.demoguidance_position.latitude,
                                                      map.demoguidance_position.longitude,
                                                      routeModel.get(0).path[pathcounter].latitude,
                                                      routeModel.get(0).path[pathcounter].longitude);
                console.log("next_distance:",next_distance);

                // calculate direction
                var next_direction = calculateDirection(map.demoguidance_position.latitude,
                                                        map.demoguidance_position.longitude,
                                                        routeModel.get(0).path[pathcounter].latitude,
                                                        routeModel.get(0).path[pathcounter].longitude);
                console.log("next_direction:",next_direction);

                // set next coordidnate
                if(next_distance < 20)
                {
                    map.demoguidance_position = routeModel.get(0).path[pathcounter]
                    if(pathcounter < routeModel.get(0).path.length - 1){
                        pathcounter++
                    }
                }else{
                    setNextCoordinate(map.demoguidance_position.latitude, map.demoguidance_position.longitude,next_direction,20)
                }

                // update car_position_mapitem
                car_position_mapitem.coordinate = map.demoguidance_position

                // car_position_mapitem angle
                root.car_direction = next_direction

                // update map.center
                //map.center = map.demoguidance_position

                // report a new instruction if current position matches with the head position of the segment
                if(segmentcounter <= routeModel.get(0).segments.length - 1){
                    if(map.demoguidance_position === routeModel.get(0).segments[segmentcounter].path[0]){
                        console.log("new segment: ", segmentcounter, "/", routeModel.get(0).segments.length - 1)
                        console.log("instruction: ", routeModel.get(0).segments[segmentcounter].maneuver.instructionText)
                        segmentcounter++
                    }
                    // calculate next cross distance
                    var next_cross_distance = calculateDistance(map.demoguidance_position.latitude,
                                                                map.demoguidance_position.longitude,
                                                                routeModel.get(0).segments[segmentcounter].path[0].latitude,
                                                                routeModel.get(0).segments[segmentcounter].path[0].longitude);
                    console.log("next_cross_distance:",next_cross_distance);

                    // update progress_next_cross
                    progress_next_cross.setProgress(Math.round((next_cross_distance%300)/300*100))

                }

            }
            else
            {
                btn_guidance.sts_guide = 0
            }
		}
	}
		
	Item {
		id: btn_present_position
		x: 942
//		y: 1328
        y: 530      // for debug
		
		Button {
            id: btn_present_position_
			width: 100
			height: 100
			
			function present_position_clicked() {
                map.center = map.currentpostion
                map.zoomLevel = root.default_zoom_level
            }
			onClicked: { present_position_clicked() }
			
			Image {
				id: image_present_position
                width: 48
				height: 92
				anchors.verticalCenter: parent.verticalCenter
				anchors.horizontalCenter: parent.horizontalCenter
                source: "images/207px-Car_icon_top.svg.png"
			}
		}
	}
	
	BtnMapDirection {
        id: btn_map_direction
		x: 15
		y: 20
	}

    BtnGuidance {
        id: btn_guidance
		x: 940
		y: 20
	}

	BtnShrink {
        id: btn_shrink
		x: 23
//		y:1200
        y:400   // for debug
	}

	BtnEnlarge {
        id: btn_enlarge
		x: 23
//		y: 1330
        y:530   // for debug
	}

	ImgDestinationDirection {
        id: img_destination_direction
		x: 120
		y: 20
	}

    ProgressNextCross {
        id: progress_next_cross
		x: 225
		y: 20
	}
}
