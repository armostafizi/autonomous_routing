for i in {1..5}; do
    echo Rep, $i
    ./controller.py "random"
    ./controller.py "dijkstra"
    ./controller.py "dijkstraBounded"
    ./controller.py "lessCarAhead"
    ./controller.py "dynamicRandom"
    #./controller.py "decmcts"
    #python controller.py "decmcts1Block"
    #python controller.py "decmcts1.5Block"
    #python controller.py "decmcts2Block"
    # python controller.py "decmcts5Block"
done
