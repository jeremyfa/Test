
class State
{
    String name;
    StringHash nameHash;

    float timeInState;

    State()
    {
        Print("State()");
    }

    ~State()
    {
        Print("~State() " + String(name));
    }

    void Enter(State@ lastState)
    {

    }

    void Exit(State@ nextState)
    {
        timeInState = 0;
    }

    void Update(float dt)
    {
        timeInState += dt;
    }

    void DebugDraw(DebugRenderer@ debug)
    {

    }

    String GetDebugText()
    {
        return " name=" + name + " timeInState=" + String(timeInState);
    }

    void SetName(const String&in s)
    {
        name = s;
        nameHash = StringHash(name);
    }
};


class FSM
{
    Array<State@>   states;
    State@          currentState;

    FSM()
    {
        Print("FSM()");
    }

    ~FSM()
    {
        Print("~FSM()");
        @currentState = null;
        states.Clear();
    }

    void AddState(State@ state)
    {
        states.Push(state);
    }

    State@ FindState(const String&in name)
    {
        return FindState(StringHash(name));
    }

    State@ FindState(const StringHash&in nameHash)
    {
        for (uint i=0; i<states.length; ++i)
        {
            if (states[i].nameHash == nameHash)
                return states[i];
        }
        return null;
    }

    void ChangeState(const StringHash&in nameHash)
    {
        State@ newState = FindState(nameHash);
        if (currentState is newState)
            return;

        State@ oldState = currentState;
        if (oldState !is null)
            oldState.Exit(newState);

        if (newState !is null)
            newState.Enter(oldState);

        @currentState = @newState;

        String oldStateName = "null";
        if (oldState !is null)
            oldStateName = oldState.name;

        String newStateName = "null";
        if (newState !is null)
            newStateName = newState.name;

        Print("FSM Change State " + oldStateName + " -> " + newStateName);
    }

    void ChangeState(const String&in name)
    {
        ChangeState(StringHash(name));
    }

    void Update(float dt)
    {
        if (currentState !is null)
            currentState.Update(dt);
    }

    void DebugDraw(DebugRenderer@ debug)
    {
        if (currentState !is null)
            currentState.DebugDraw(debug);
    }

    String GetDebugText()
    {
        String ret = "current-state = ";
        if (currentState !is null)
            ret += currentState.GetDebugText();
        else
            ret += "null";
        return ret + "\n";
    }
};