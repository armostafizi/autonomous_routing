#!/usr/bin/python

def update_routes_quickest(netlogo, network, cars):
    import networkx as nx
    for car in cars:
        if car.stopped and car.direction == 'east':
            next_intersection = car.next_intersection.to_tuple()
            destination = car.destination.to_tuple()
            route = nx.shortest_path(network, next_intersection, destination, 'time')
            car.push_route_netlogo(netlogo, route, mode = 'remaining')

