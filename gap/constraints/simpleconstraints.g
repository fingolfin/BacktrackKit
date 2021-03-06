# Any refiner which can be expressed as "stabilize an ordered partition"
# can be implemented easily and efficently, as we only need to handle
# the root node of search (as we never gain more information from such a
# constraint as search progresses).
# Therefore we have two general functions which implement:
#
# MakeFixlistStabilizer: Returns the constraint which implements
#                        fixlist[i] = fixlist[i^p]
#
# MakeFixListTransporter: Returns the constraint which implements
#                         fixlistL[i] = fixlistR[i^p]
#
# These are used to then implement refiners for sets, tuples
# and ordered partitions.

# Make a refiner which accepts permutations p
# such that fixlist[i] = fixlist[i^p]
BTKit_MakeFixlistStabilizer := function(name, fixlist)
    local filters;
    filters := {i} -> fixlist[i];
    return rec(
        name := name,
        check := {p} -> ForAll([1..Length(fixlist)], {i} -> fixlist[i] = fixlist[i^p]),
        refine := rec(
            initialise := function(ps, buildingRBase)
                return filters;
            end)
    );
end;

# Make a refiner which accepts permutations p
# such that fixlistL[i] = fixlistR[i^p]
BTKit_MakeFixlistTransporter := function(name, fixlistL, fixlistR)
    local filtersL, filtersR;
    filtersL := {i} -> fixlistL[i];
    filtersR := {i} -> fixlistR[i];
    return rec(
        name := name,
        check := {p} -> ForAll([1..Length(fixlistL)], {i} -> fixlistL[i] = fixlistR[i^p]),
        refine := rec(
            initialise := function(ps, buildingRBase)
                if buildingRBase then
                    return filtersL;
                else
                    return filtersR;
                fi;
            end)
    );
end;

BTKit_Con.TupleStab := function(n, fixpoints)
    local fixlist, i;
    fixlist := ListWithIdenticalEntries(n, 0);
    for i in [1..Length(fixpoints)] do
        fixlist[fixpoints[i]] := i;
    od;
    return BTKit_MakeFixlistStabilizer("TupleStab", fixlist);
end;

BTKit_Con.TupleTransporter := function(n, fixpointsL, fixpointsR)
    local fixlistL, fixlistR, i;
    fixlistL := ListWithIdenticalEntries(n, 0);
    for i in [1..Length(fixpointsL)] do
        fixlistL[fixpointsL[i]] := i;
    od;
    fixlistR := ListWithIdenticalEntries(n, 0);
    for i in [1..Length(fixpointsR)] do
        fixlistR[fixpointsR[i]] := i;
    od;
    return BTKit_MakeFixlistTransporter("TupleTransport", fixlistL, fixlistR);
end;

BTKit_Con.SetStab := function(n, fixset)
    local fixlist, i;
    fixlist := ListWithIdenticalEntries(n, 0);
    for i in [1..Length(fixset)] do
        fixlist[fixset[i]] := 1;
    od;
    return BTKit_MakeFixlistStabilizer("SetStab", fixlist);
end;

BTKit_Con.SetTransporter := function(n, fixsetL, fixsetR)
    local fixlistL, fixlistR, i;
    fixlistL := ListWithIdenticalEntries(n, 0);
    for i in [1..Length(fixsetL)] do
        fixlistL[fixsetL[i]] := 1;
    od;
    fixlistR := ListWithIdenticalEntries(n, 0);
    for i in [1..Length(fixsetR)] do
        fixlistR[fixsetR[i]] := 1;
    od;
    return BTKit_MakeFixlistTransporter("SetTransport", fixlistL, fixlistR);
end;

BTKit_Con.OrderedPartitionStab := function(n, fixpart)
    local fixlist, i, j;
    fixlist := ListWithIdenticalEntries(n, 0);
    for i in [1..Length(fixpart)] do
        for j in fixpart[i] do
            fixlist[j] := i;
        od;
    od;
    return BTKit_MakeFixlistStabilizer("OrderedPartitionStab", fixlist);
end;

BTKit_Con.OrderedPartitionTransporter := function(n, fixpartL, fixpartR)
    local fixlistL, fixlistR, i, j;
    fixlistL := ListWithIdenticalEntries(n, 0);
    for i in [1..Length(fixpartL)] do
        for j in fixpartL[i] do
            fixlistL[j] := i;
        od;
    od;
    fixlistR := ListWithIdenticalEntries(n, 0);
    for i in [1..Length(fixpartR)] do
        for j in fixpartR[i] do
            fixlistR[j] := i;
        od;
    od;
    return BTKit_MakeFixlistTransporter("OrdredPartitionTransport", fixlistL, fixlistR);
end;


# The following refiner is probably the most complex. It implements
# 'permutation is in group given by list of generators'.
#
# Exactly why this refiner works, and why we use 'RepresentativeAction',
# requires more explanation than fits in this comment. However, every
# other refiner we have ever seen does not need to worry about the values
# in the rBase, so don't use this as a model for another refiner, unless
# that one is also based around a group given as a list of generators.
BTKit_Con.InGroup := function(n, group)
    local orbList,fillOrbits, orbMap, pointMap, r;
    fillOrbits := function(pointlist)
        local orbs, array, i, j;
        # caching
        if IsBound(pointMap[pointlist]) then
            return pointMap[pointlist];
        fi;

        orbs := Orbits(Stabilizer(group, pointlist, OnTuples), [1..n]);
        orbMap[pointlist] := Set(orbs, Set);
        array := [];
        for i in [1..Length(orbs)] do
            for j in orbs[i] do
                array[j] := i;
            od;
        od;
        pointMap[pointlist] := array;
        return array;
    end;

    # OrbMap is unused?
    orbMap := HashMap();
    pointMap := HashMap();

    r := rec(
        name := "InGroup",
        check := {p} -> p in group,
        refine := rec(
            rBaseFinished := function(getRBase)
                r.RBase := getRBase;
            end,
            initialise := function(ps, buildingRBase)
                local fixedpoints, mapval, points;
                fixedpoints := PS_FixedPoints(ps);
                points := fillOrbits(fixedpoints);
                return {x} -> points[x];
            end,
            changed := function(ps, buildingRBase)
                local fixedpoints, points, fixedps, fixedrbase, p;
                if buildingRBase then
                    fixedpoints := PS_FixedPoints(ps);
                    points := fillOrbits(fixedpoints);
                    return {x} -> points[x];
                else
                    fixedps := PS_FixedPoints(ps);
                    fixedrbase := PS_FixedPoints(r.RBase);
                    fixedrbase := fixedrbase{[1..Length(fixedps)]};
                    p := RepresentativeAction(group, fixedps, fixedrbase, OnTuples);
                    Info(InfoBTKit, 1, "Find mapping (InGroup):\n"
                         , "    fixed points:   ", fixedps, "\n"
                         , "    fixed by rbase: ", fixedrbase, "\n"
                         , "    map:            ", p);

                    if p = fail then
                        return fail;
                    fi;
                    # this could as well call fillOrbits
                    points := pointMap[fixedrbase];
                    return {x} -> points[x^p];
                fi;
            end)
        );
        return r;
    end;



