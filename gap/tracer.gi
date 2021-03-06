##
##  This file defines tracers.
##

InstallGlobalFunction(RecordingTracer,
{} -> Objectify(RecordingTracerTypeMutable, rec(trace := []) ));

InstallMethod(AddEvent, [IsRecordingTracerRep and IsMutable, IsObject],
    function(tracer, o)
        Add(tracer!.trace, o);
        return true;
    end);

InstallMethod(TraceLength, [IsRecordingTracerRep],
{x} -> Length(x!.trace));
InstallMethod(TraceEvent, [IsRecordingTracerRep, IsPosInt],
{x,i} -> x!.trace[i]);

InstallMethod(ViewObj, [IsRecordingTracerRep],
function(t)
    PrintFormatted("<recording tracer of length {}>", TraceLength(t));
end);


InstallGlobalFunction(FollowingTracer,
function(trace)
    if IsFollowingTracerRep(trace) then
        ErrorNoReturn("a following tracer cannot follow a following tracer,");
    fi;
    return Objectify(FollowingTracerTypeMutable,
        rec(existingTrace := trace, pos := 1) );
end);

InstallMethod(AddEvent, [IsFollowingTracerRep and IsMutable, IsObject],
    function(tracer, o)
        if tracer!.pos > TraceLength(tracer!.existingTrace) then
            Info(InfoTrace, 1, "Too long!");
            return false;
        elif TraceEvent(tracer!.existingTrace, tracer!.pos) <> o then
            Info(InfoTrace, 1, StringFormatted("Trace violation {}:{}",
                               TraceEvent(tracer!.existingTrace, tracer!.pos), o));
            tracer!.pos := infinity;
            return false;
        fi;
        tracer!.pos := tracer!.pos + 1;
        return true;
    end);

InstallMethod(TraceLength, [IsFollowingTracerRep],
{x} -> TraceLength(x!.existingTrace));
InstallMethod(TraceEvent, [IsFollowingTracerRep, IsPosInt],
{x,i} -> TraceEvent(x!.existingTrace, i));

InstallMethod(ViewObj, [IsFollowingTracerRep],
function(t)
    PrintFormatted("<following tracer of length {}>", TraceLength(t));
end);


InstallGlobalFunction(CanonicalisingTracer,
{} -> Objectify(CanonicalisingTracerTypeMutable, rec(trace := [], pos := 1)));
