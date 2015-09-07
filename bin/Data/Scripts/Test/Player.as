#include "Scripts/Test/Character.as"

class PlayerStandState : CharacterState
{
    Array<String>           animations;

    PlayerStandState(Character@ c)
    {
        super(c);
        name = "StandState";
        animations.Push("Animation/Stand_Idle.ani");
        animations.Push("Animation/Stand_Idle_01.ani");
        animations.Push("Animation/Stand_Idle_02.ani");
    }

    void Enter(State@ lastState)
    {
        PlayAnimation(ownner.animCtrl, animations[RandomInt(animations.length)], LAYER_MOVE, true, 0.25f);
    }

    void Update(float dt)
    {
        if (!gInput.inLeftStickInDeadZone() && gInput.isLeftStickStationary())
        {
            int index = RadialSelectAnimation_Player(ownner.sceneNode, 4);
            ownner.sceneNode.vars["AnimationIndex"] = index;
            if (index == 0)
                ownner.stateMachine.ChangeState("MoveState");
            else
                ownner.stateMachine.ChangeState("StandToMoveState");
        }

        if (gInput.isAttackPressed()) {
            Print("Attack!!");
            ownner.stateMachine.ChangeState("AttackState");
        }
        else if(gInput.isCounterPressed()) {
            Print("Counter");
            ownner.stateMachine.ChangeState("CounterState");
        }
    }
};

class PlayerStandToMoveState : MultiMotionState
{
    PlayerStandToMoveState(Character@ c)
    {
        super(c);
        name = "StandToMoveState";
        motions.Push(Motion("Animation/Stand_To_Walk_Right_90.ani", 90, 36, false, true, 1.5));
        motions.Push(Motion("Animation/Stand_To_Walk_Right_180.ani", 180, 22, false, true, 1.0));
        motions.Push(Motion("Animation/Stand_To_Walk_Left_90.ani", -90, 26, false, true, 1.5));
        // motions.Push(Motion("Animation/Stand_To_Walk_Left_180.ani", -180, 17, false, true));
    }

    void Update(float dt)
    {
        if (motions[selectIndex].Move(dt, ownner.sceneNode, ownner.animCtrl))
        {
            if (gInput.inLeftStickInDeadZone() && gInput.hasLeftStickBeenStationary(0.1))
                ownner.stateMachine.ChangeState("StandState");
            else {
                ownner.animCtrl.SetSpeed(motions[selectIndex].name, 1);
                ownner.stateMachine.ChangeState("MoveState");
            }
        }
    }

    int PickIndex()
    {
        return ownner.sceneNode.vars["AnimationIndex"].GetInt() - 1;
    }
};

class PlayerMoveState : CharacterState
{
    Motion@ motion;

    PlayerMoveState(Character@ c)
    {
        super(c);
        name = "MoveState";
        @motion = Motion("Animation/Walk_Forward.ani", 0, -1, true, false);
    }

    void Update(float dt)
    {
        // check if we should return to the idle state
        if (gInput.inLeftStickInDeadZone() && gInput.hasLeftStickBeenStationary(0.1))
            ownner.stateMachine.ChangeState("StandState");

        // compute the difference between the direction the character is facing
        // and the direction the user wants to go in
        float characterDifference = ComputeDifference_Player(ownner.sceneNode)  ;

        // if the difference is greater than this about, turn the character
        float fullTurnThreashold = 115;
        float turnSpeed = 5;

        ownner.sceneNode.Yaw(characterDifference * turnSpeed * dt);
        motion.Move(dt, ownner.sceneNode, ownner.animCtrl);

        // if the difference is large, then turn 180 degrees
        if ( (Abs(characterDifference) > fullTurnThreashold) && gInput.isLeftStickStationary() )
        {
            Print("Turn 180!!!");
            ownner.stateMachine.ChangeState("MoveTurn180State");
        }
    }

    void Enter(State@ lastState)
    {
        PlayerStandToMoveState@ standToMoveState = cast<PlayerStandToMoveState@>(lastState);
        float startTime = 0.0f;
        float blendTime = 0.2f;
        if (standToMoveState !is null)
        {
            Array<float> startTimes = {13.0f/30.0f, 13.0f/30.0f, 2.0f/30.0f};
            startTime = startTimes[standToMoveState.selectIndex];
            blendTime = 0.25f;
        }
        else {
            PlayerMoveTurn180State@ turn180State = cast<PlayerMoveTurn180State>(lastState);
            if (turn180State !is null)
                startTime = 13.0f/30.0f;
        }
        motion.Start(ownner.sceneNode, ownner.animCtrl, startTime, blendTime);
    }

    void DebugDraw(DebugRenderer@ debug)
    {
        motion.DebugDraw(debug, ownner.sceneNode);
    }
};

class PlayerMoveTurn180State : CharacterState
{
    Motion@ motion;

    PlayerMoveTurn180State(Character@ c)
    {
        super(c);
        name = "MoveTurn180State";
        @motion = Motion("Animation/Stand_To_Walk_Right_180.ani", 180, 22, false, true, 1.0);
    }

    void Update(float dt)
    {
        if (motion.Move(dt, ownner.sceneNode, ownner.animCtrl))
        {
            if (gInput.inLeftStickInDeadZone() && gInput.hasLeftStickBeenStationary(0.1))
                ownner.stateMachine.ChangeState("StandState");
            else {
                ownner.stateMachine.ChangeState("MoveState");
            }
        }
    }

    void Enter(State@ lastState)
    {
        motion.Start(ownner.sceneNode, ownner.animCtrl, 0.0f, 0.1f);
    }

    void DebugDraw(DebugRenderer@ debug)
    {
        motion.DebugDraw(debug, ownner.sceneNode);
    }
};

class PlayerAttackState : MultiMotionState
{
    PlayerAttackState(Character@ c)
    {
        super(c);
        name = "AttackState";
        motions.Push(Motion("Animation/Attack_Close_Forward_07.ani", 0, -1, false, false));
        motions.Push(Motion("Animation/Attack_Close_Forward_08.ani", 0, -1, false, false));
    }

    void Update(float dt)
    {
        if (motions[selectIndex].Move(dt, ownner.sceneNode, ownner.animCtrl))
            ownner.stateMachine.ChangeState("StandState");
    }

    int PickIndex()
    {
        return RandomInt(motions.length);
    }
};


class PlayerEvadeState : MultiMotionState
{
    PlayerEvadeState(Character@ c)
    {
        super(c);
        name = "EvadeState";
        motions.Push(Motion("Animation/Attack_Close_Forward_07.ani", 0, -1, false, false));
        motions.Push(Motion("Animation/Attack_Close_Forward_08.ani", 0, -1, false, false));
    }

    void Update(float dt)
    {
        if (motions[selectIndex].Move(dt, ownner.sceneNode, ownner.animCtrl))
            ownner.stateMachine.ChangeState("StandState");
    }

    int PickIndex()
    {
        return RandomInt(motions.length);
    }
};

class PlayerAlignState : CharacterAlignState
{
    PlayerAlignState(Character@ c)
    {
        super(c);
    }
};

class PlayerCounterState : MultiMotionState
{
    PlayerCounterState(Character@ c)
    {
        super(c);
        name = "CounterState";
        //motions.Push(Motion("Animation/Attack_Close_Forward_07.ani", 0, -1, false, false));
        //motions.Push(Motion("Animation/Attack_Close_Forward_08.ani", 0, -1, false, false));
        motions.Push(Motion("Animation/Counter_Arm_Front_01.ani", 0, -1, false, false));
        // motions.Push(Motion("Animation/Counter_Arm_Front_01_TG.ani", 0, -1, false, false));
    }

    void Update(float dt)
    {
        if (motions[selectIndex].Move(dt, ownner.sceneNode, ownner.animCtrl))
            ownner.stateMachine.ChangeState("StandState");
    }

    int PickIndex()
    {
        return RandomInt(motions.length);
    }
};

class Player : Character
{
    int combo;

    Player()
    {
        super();
        combo = 0;
    }

    void Start()
    {
        Character::Start();
        stateMachine.AddState(PlayerStandState(this));
        stateMachine.AddState(PlayerStandToMoveState(this));
        stateMachine.AddState(PlayerMoveState(this));
        stateMachine.AddState(PlayerMoveTurn180State(this));
        stateMachine.AddState(PlayerAttackState(this));
        stateMachine.AddState(PlayerAlignState(this));
        stateMachine.AddState(PlayerCounterState(this));
        stateMachine.AddState(PlayerEvadeState(this));
        stateMachine.ChangeState("StandState");
    }

    void Update(float dt)
    {
        // Print("Player::Update " + String(dt));
        Character::Update(dt);
    }

    void DebugDraw(DebugRenderer@ debug)
    {
        debug.AddNode(sceneNode, 1.0f, false);
        debug.AddNode(sceneNode.GetChild("Bip01", true), 1.0f, false);
        Vector3 fwd = Vector3(0, 0, 1);
        Vector3 camDir = cameraNode.worldRotation * fwd;
        float cameraAngle = Atan2(camDir.x, camDir.z);
        Vector3 characterDir = sceneNode.worldRotation * fwd;
        float characterAngle = Atan2(characterDir.x, characterDir.z);
        float targetAngle = cameraAngle + gInput.m_leftStickAngle;
        float baseLen = 2.0f;
        DebugDrawDirection(debug, sceneNode, targetAngle, Color(1, 1, 0), baseLen * gInput.m_leftStickMagnitude);
        DebugDrawDirection(debug, sceneNode, characterAngle, Color(1, 0, 1), baseLen);
    }

    void Attack()
    {

    }

    String GetDebugText()
    {
        return Character::GetDebugText() +  "player combo=" + String(combo) + "\n";
    }
};


// computes the difference between the characters current heading and the
// heading the user wants them to go in.
float ComputeDifference_Player(Node@ n)
{
    // if the user is not pushing the stick anywhere return.  this prevents the character from turning while stopping (which
    // looks bad - like the skid to stop animation)
    if( gInput.m_leftStickMagnitude < 0.5f )
        return 0;

    Vector3 camDir = cameraNode.worldRotation * Vector3(0, 0, 1);
    float cameraAngle = Atan2(camDir.x, camDir.z);
    // check the difference between the characters current heading and the desired heading from the gamepad
    return computeDifference(n, gInput.m_leftStickAngle + cameraAngle);
}

//  divides a circle into numSlices and returns the index (in clockwise order) of the slice which
//  contains the gamepad's angle relative to the camera.
int RadialSelectAnimation_Player(Node@ n, int numDirections)
{
    Vector3 fwd = Vector3(0, 0, 1);
    Vector3 camDir = n.worldRotation * fwd;
    float cameraAngle = Atan2(camDir.x, camDir.z);
    return RadialSelectAnimation(n, numDirections, gInput.m_leftStickAngle + cameraAngle);
}