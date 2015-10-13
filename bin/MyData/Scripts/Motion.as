
const int LAYER_MOVE = 0;
const int LAYER_ATTACK = 1;

void PlayAnimation(AnimationController@ ctrl, const String&in name, uint layer = LAYER_MOVE, bool loop = false, float blendTime = 0.1f, float startTime = 0.0f, float speed = 1.0f)
{
    Print("PlayAnimation " + name + " loop=" + loop + " blendTime=" + blendTime + " startTime=" + startTime + " speed=" + speed);
    ctrl.StopLayer(layer, blendTime);
    ctrl.PlayExclusive(name, layer, loop, blendTime);
    ctrl.SetTime(name, startTime);
    ctrl.SetSpeed(name, speed);
}

int QueryBestCounterMotion(const Array<Motion@>&in motions1, const Array<Motion@>&in motions2, const Vector3&in posDiff)
{
    float bestErrSQR = 99999;
    int bestIndex = -1;
    for (uint i=0; i<motions1.length; ++i)
    {
        Motion@ motion1 = motions1[i];
        Motion@ motion2 = motions2[i];
        Vector3 startDiff = motion1.startFromOrigin - motion2.startFromOrigin;
        startDiff.y = 0;
        float diffSQR = (startDiff - posDiff).lengthSquared;
        if (diffSQR < bestErrSQR)
        {
            bestIndex = i;
            bestErrSQR = diffSQR;
        }
    }

    Print("QueryBestCounterMotion bestIndex=" + bestIndex + " bestErrSQR=" + bestErrSQR);
    return bestIndex;
}

int FindMotionIndex(const Array<Motion@>&in motions, const String&in name)
{
    for (uint i=0; i<motions.length; ++i)
    {
        if (motions[i].name == name)
            return i;
    }
    return -1;
}

class Motion
{
    String                  name;
    String                  animationName;
    Animation@              animation;
    Array<Vector4>          motionKeys;
    float                   endTime;
    bool                    looped;

    Vector3                 startFromOrigin;

    float                   endDistance;

    int                     endFrame;
    int                     motionFlag;
    int                     originFlag;
    int                     allowMotion;
    bool                    cutRotation;

    // ==============================================
    //   DYNAMIC VALUES
    // ==============================================
    Vector3                 startPosition;
    float                   startRotation;
    Quaternion              startRotationQua;

    float                   deltaRotation;
    Vector3                 deltaPosition;

    bool                    translateEnabled;
    bool                    rotateEnabled;

    Motion()
    {
        translateEnabled = true;
        rotateEnabled = true;
    }

    Motion(const Motion&in other)
    {
        translateEnabled = true;
        rotateEnabled = true;
        animationName = other.animationName;
        animation = other.animation;
        motionKeys = other.motionKeys;
        endTime = other.endTime;
        looped = other.looped;
        startFromOrigin = other.startFromOrigin;
        endDistance = other.endDistance;
        endFrame = other.endFrame;
        motionFlag = other.motionFlag;
        originFlag = other.originFlag;
        allowMotion = other.allowMotion;
        cutRotation = other.cutRotation;
    }

    ~Motion()
    {
        @animation = null;
    }

    void Process()
    {
        uint startTime = time.systemTime;
        this.animationName = GetAnimationName(this.name);
        this.animation = cache.GetResource("Animation", animationName);
        gMotionMgr.memoryUse += this.animation.memoryUse;
        bool dump = false;
        ProcessAnimation(animationName, motionFlag, originFlag, allowMotion, cutRotation, motionKeys, startFromOrigin, dump);
        SetEndFrame(endFrame);
        Vector4 v = motionKeys[0];
        Vector4 diff = motionKeys[endFrame - 1] - motionKeys[0];
        endDistance = Vector3(diff.x, diff.y, diff.z).length;
        Print("Motion " + name + " endDistance="  + endDistance + " timeCost=" + String(time.systemTime - startTime) + " ms startFromOrigin=" + startFromOrigin.ToString());
    }

    void SetEndFrame(float frame)
    {
        endFrame = frame;
        if (endFrame < 0)
            endFrame = motionKeys.length - 1;
        endTime = float(endFrame) / FRAME_PER_SEC;
    }

    void GetMotion(float t, float dt, bool loop, Vector4& out out_motion)
    {
        if (motionKeys.empty)
            return;

        float future_time = t + dt;
        if (future_time > animation.length && loop) {
            Vector4 t1 = Vector4(0,0,0,0);
            Vector4 t2 = Vector4(0,0,0,0);
            GetMotion(t, animation.length - t, false, t1);
            GetMotion(0, t + dt - animation.length, false, t2);
            out_motion = t1 + t2;
        }
        else
        {
            Vector4 k1 = GetKey(t);
            Vector4 k2 = GetKey(future_time);
            out_motion = k2 - k1;
        }
    }

    Vector4 GetKey(float t)
    {
        if (motionKeys.empty)
            return Vector4(0, 0, 0, 0);

        uint i = uint(t * FRAME_PER_SEC);
        if (i >= motionKeys.length)
            i = motionKeys.length - 1;
        Vector4 k1 = motionKeys[i];
        uint next_i = i + 1;
        if (next_i >= motionKeys.length)
            next_i = motionKeys.length - 1;
        if (i == next_i)
            return k1;
        Vector4 k2 = motionKeys[next_i];
        float a = t*FRAME_PER_SEC - float(i);
        // float a =  (t - float(i)*SEC_PER_FRAME)/SEC_PER_FRAME;
        return k1.Lerp(k2, a);
    }

    void Start(Character@ object, float localTime = 0.0f, float blendTime = 0.1, float speed = 1.0f)
    {
        PlayAnimation(object.animCtrl, animationName, LAYER_MOVE, looped, blendTime, localTime, speed);
        startPosition = object.sceneNode.worldPosition;
        startRotationQua = object.sceneNode.worldRotation;
        startRotation = startRotationQua.eulerAngles.y;
        deltaRotation = 0;
        deltaPosition = Vector3(0, 0, 0);
        translateEnabled = true;
        rotateEnabled = true;
        // Print("motion " + animationName + " start-position=" + startPosition.ToString() + " start-rotation=" + startRotation);
    }

    bool Move(Character@ object, float dt)
    {
        AnimationController@ ctrl = object.animCtrl;
        Node@ _node = object.sceneNode;
        float localTime = ctrl.GetTime(animationName);
        if (looped)
        {
            Vector4 motionOut = Vector4(0, 0, 0, 0);
            GetMotion(localTime, dt, looped, motionOut);

            if (rotateEnabled)
                _node.Yaw(motionOut.w);

            if (translateEnabled)
            {
                Vector3 tLocal(motionOut.x, motionOut.y, motionOut.z);
                tLocal = tLocal * ctrl.GetWeight(animationName);
                Vector3 tWorld = _node.worldRotation * tLocal + _node.worldPosition + deltaPosition;
                object.MoveTo(tWorld, dt);
            }
            else {
                object.SetVelocity(Vector3(0, 0, 0));
            }
        }
        else
        {
            Vector4 motionOut = GetKey(localTime);
            if (rotateEnabled)
                _node.worldRotation = Quaternion(0, startRotation + motionOut.w + deltaRotation, 0);

            if (translateEnabled)
            {
                Vector3 tWorld = startRotationQua * Vector3(motionOut.x, motionOut.y, motionOut.z) + startPosition + deltaPosition;
                object.MoveTo(tWorld, dt);
            }
            else {
                object.SetVelocity(Vector3(0, 0, 0));
            }
        }
        return localTime >= endTime;
    }

    Vector3 GetFuturePosition(Node@ _node, float t)
    {
        Vector4 motionOut = GetKey(t);
        return _node.worldRotation * Vector3(motionOut.x, motionOut.y, motionOut.z) + _node.worldPosition;
    }

    Vector3 GetFuturePosition(float t)
    {
        Vector4 motionOut = GetKey(t);
        return startRotationQua * Vector3(motionOut.x, motionOut.y, motionOut.z) + startPosition;
    }

    void DebugDraw(DebugRenderer@ debug, Node@ _node)
    {
        if (looped) {
            Vector4 tFinnal = GetKey(endTime);
            Vector3 tLocal(tFinnal.x, tFinnal.y, tFinnal.z);
            debug.AddLine(_node.worldRotation * tLocal + _node.worldPosition, _node.worldPosition, Color(0.5f, 0.5f, 0.7f), false);
        }
        else {
            Vector4 tFinnal = GetKey(endTime);
            debug.AddLine(startRotationQua * Vector3(tFinnal.x, tFinnal.y, tFinnal.z) + startPosition,  startPosition, Color(0.5f, 0.5f, 0.7f), false);
            DebugDrawDirection(debug, _node, startRotation + tFinnal.w, Color(0,1,0), 2.0);
        }
    }
};

void DebugDrawDirection(DebugRenderer@ debug, Node@ _node, const Quaternion&in rotation, const Color&in color, float radius = 1.0, float yAdjust = 0)
{
    Vector3 dir = rotation * Vector3(0, 0, 1);
    float angle = Atan2(dir.x, dir.z);
    DebugDrawDirection(debug, _node, angle, color, radius, yAdjust);
}

void DebugDrawDirection(DebugRenderer@ debug, Node@ _node, float angle, const Color&in color, float radius = 1.0, float yAdjust = 0)
{
    Vector3 start = _node.worldPosition;
    start.y = yAdjust;
    Vector3 end = start + Vector3(Sin(angle) * radius, 0, Cos(angle) * radius);
    debug.AddLine(start, end, color, false);
}

class AttackMotion
{
    Motion@         motion;
    float           impactTime;
    float           impactDist;
    float           counterStartTime;
    Vector3         impactPosition;
    Vector2         slowMotionTime;

    AttackMotion(const String&in name, int impactFrame, int counterStartFrame = -1)
    {
        @motion = gMotionMgr.FindMotion(name);
        impactTime = impactFrame * SEC_PER_FRAME;
        Vector4 k = motion.motionKeys[impactFrame];
        impactPosition = Vector3(k.x, k.y, k.z);
        impactDist = impactPosition.length;
        slowMotionTime.x = impactTime - SEC_PER_FRAME * 5;
        slowMotionTime.y = impactTime + SEC_PER_FRAME * 5;
        counterStartTime = counterStartFrame * SEC_PER_FRAME;
        if (counterStartFrame > 0)
        {
            slowMotionTime.x = counterStartTime;
            slowMotionTime.y = impactTime;
        }
    }

    int opCmp(const AttackMotion&in obj)
    {
        if (impactDist > obj.impactDist)
            return 1;
        else if (impactDist < obj.impactDist)
            return -1;
        else
            return 0;
    }
};

class MotionManager
{
    Array<Motion@>          motions;
    uint                    memoryUse;

    MotionManager()
    {
        Print("MotionManager");
    }


    Motion@ FindMotion(const String&in name)
    {
        for (uint i=0; i<motions.length; ++i)
        {
            if (motions[i].name == name)
                return motions[i];
        }
        log.Error("Could not find " + name);
        return null;
    }

    void Start()
    {
        uint startTime = time.systemTime;

        PreProcess();

        //========================================================================
        // PLAYER MOTIONS
        //========================================================================
        // Locomotions
        CreateMotion("BM_Combat_Movement/Turn_Right_90", kMotion_XZR, kMotion_R, 16, 0, false);
        CreateMotion("BM_Combat_Movement/Turn_Right_180", kMotion_XZR, kMotion_R, 28, 0, false);
        CreateMotion("BM_Combat_Movement/Turn_Left_90", kMotion_XZR, kMotion_R, 22, 0, false);
        CreateMotion("BM_Combat_Movement/Walk_Forward", kMotion_XZR, kMotion_Z, -1, 0, true);

        CreateMotion("BM_Movement/Turn_Right_90", kMotion_R, kMotion_R, 16, 0, false);
        CreateMotion("BM_Movement/Turn_Right_180", kMotion_R, kMotion_R, 25, 0, false);
        CreateMotion("BM_Movement/Turn_Left_90", kMotion_R, kMotion_R, 14, 0, false);
        CreateMotion("BM_Movement/Walk_Forward", kMotion_Z, kMotion_Z, -1, 0, true);

        // Evades
        CreateMotion("BM_Combat/Evade_Forward_01", kMotion_XZR, kMotion_ZR, -1, 0, false);
        CreateMotion("BM_Combat/Evade_Right_01", kMotion_XZR, kMotion_XR, -1, 0, false, true);
        CreateMotion("BM_Combat/Evade_Back_01", kMotion_XZR, kMotion_ZR, -1, 0, false);
        CreateMotion("BM_Combat/Evade_Left_01", kMotion_XZR, kMotion_XR, -1, 0, false, true);

        CreateMotion("BM_Combat/Redirect", kMotion_XZR, kMotion_XZR, 58);

        String hitPrefix = "BM_Combat_HitReaction/";
        CreateMotion(hitPrefix + "HitReaction_Back");
        CreateMotion(hitPrefix + "HitReaction_Face_Left");
        CreateMotion(hitPrefix + "HitReaction_Face_Right");
        CreateMotion(hitPrefix + "Hit_Reaction_SideLeft");
        CreateMotion(hitPrefix + "Hit_Reaction_SideRight");
        CreateMotion(hitPrefix + "HitReaction_Stomach");

        // Attacks
        String preFix = "BM_Attack/";
        //========================================================================
        // FORWARD
        //========================================================================
        // weak forward
        CreateMotion(preFix + "Attack_Close_Weak_Forward");
        CreateMotion(preFix + "Attack_Close_Weak_Forward_01");
        CreateMotion(preFix + "Attack_Close_Weak_Forward_02");
        CreateMotion(preFix + "Attack_Close_Weak_Forward_03");
        CreateMotion(preFix + "Attack_Close_Weak_Forward_04");
        CreateMotion(preFix + "Attack_Close_Weak_Forward_05");
        // close forward
        CreateMotion(preFix + "Attack_Close_Forward_02");
        CreateMotion(preFix + "Attack_Close_Forward_03");
        CreateMotion(preFix + "Attack_Close_Forward_04");
        CreateMotion(preFix + "Attack_Close_Forward_05");
        CreateMotion(preFix + "Attack_Close_Forward_06");
        CreateMotion(preFix + "Attack_Close_Forward_07");
        CreateMotion(preFix + "Attack_Close_Forward_08");
        CreateMotion(preFix + "Attack_Close_Run_Forward");
        // far forward
        CreateMotion(preFix + "Attack_Far_Forward");
        CreateMotion(preFix + "Attack_Far_Forward_01");
        CreateMotion(preFix + "Attack_Far_Forward_02");
        CreateMotion(preFix + "Attack_Far_Forward_03");
        CreateMotion(preFix + "Attack_Far_Forward_04");
        CreateMotion(preFix + "Attack_Run_Far_Forward");

        //========================================================================
        // RIGHT
        //========================================================================
        // weak right
        CreateMotion(preFix + "Attack_Close_Weak_Right");
        CreateMotion(preFix + "Attack_Close_Weak_Right_01");
        CreateMotion(preFix + "Attack_Close_Weak_Right_02");
        // close right
        CreateMotion(preFix + "Attack_Close_Right");
        CreateMotion(preFix + "Attack_Close_Right_01");
        CreateMotion(preFix + "Attack_Close_Right_03");
        CreateMotion(preFix + "Attack_Close_Right_04");
        CreateMotion(preFix + "Attack_Close_Right_05");
        CreateMotion(preFix + "Attack_Close_Right_06");
        CreateMotion(preFix + "Attack_Close_Right_07");
        CreateMotion(preFix + "Attack_Close_Right_08");
        // far right
        CreateMotion(preFix + "Attack_Far_Right");
        CreateMotion(preFix + "Attack_Far_Right_01");
        CreateMotion(preFix + "Attack_Far_Right_02");
        CreateMotion(preFix + "Attack_Far_Right_03");
        CreateMotion(preFix + "Attack_Far_Right_04");

        //========================================================================
        // BACK
        //========================================================================
        // weak back
        CreateMotion(preFix + "Attack_Close_Weak_Back");
        CreateMotion(preFix + "Attack_Close_Weak_Back_01");
        // close back
        CreateMotion(preFix + "Attack_Close_Back");
        CreateMotion(preFix + "Attack_Close_Back_01");
        CreateMotion(preFix + "Attack_Close_Back_02");
        CreateMotion(preFix + "Attack_Close_Back_03");
        CreateMotion(preFix + "Attack_Close_Back_04");
        CreateMotion(preFix + "Attack_Close_Back_05");
        CreateMotion(preFix + "Attack_Close_Back_06");
        CreateMotion(preFix + "Attack_Close_Back_07");
        CreateMotion(preFix + "Attack_Close_Back_08");
        // far back
        CreateMotion(preFix + "Attack_Far_Back");
        CreateMotion(preFix + "Attack_Far_Back_01");
        CreateMotion(preFix + "Attack_Far_Back_02");
        CreateMotion(preFix + "Attack_Far_Back_03");
        CreateMotion(preFix + "Attack_Far_Back_04");

        //========================================================================
        // LEFT
        //========================================================================
        // weak left
        CreateMotion(preFix + "Attack_Close_Weak_Left");
        CreateMotion(preFix + "Attack_Close_Weak_Left_01");
        CreateMotion(preFix + "Attack_Close_Weak_Left_02");

        // close left
        CreateMotion(preFix + "Attack_Close_Left");
        CreateMotion(preFix + "Attack_Close_Left_01");
        CreateMotion(preFix + "Attack_Close_Left_02");
        CreateMotion(preFix + "Attack_Close_Left_03");
        CreateMotion(preFix + "Attack_Close_Left_04");
        CreateMotion(preFix + "Attack_Close_Left_05");
        CreateMotion(preFix + "Attack_Close_Left_06");
        CreateMotion(preFix + "Attack_Close_Left_07");
        CreateMotion(preFix + "Attack_Close_Left_08");
        // far left
        CreateMotion(preFix + "Attack_Far_Left");
        CreateMotion(preFix + "Attack_Far_Left_01");
        CreateMotion(preFix + "Attack_Far_Left_02");
        CreateMotion(preFix + "Attack_Far_Left_03");
        CreateMotion(preFix + "Attack_Far_Left_04");

        AddCounterMotions("BM_TG_Counter/");

        //========================================================================
        // THUG MOTIONS
        //========================================================================
        preFix = "TG_Combat/";
        CreateMotion(preFix + "Step_Forward", kMotion_Z);
        CreateMotion(preFix + "Step_Right", kMotion_X);
        CreateMotion(preFix + "Step_Back", kMotion_Z);
        CreateMotion(preFix + "Step_Left", kMotion_X);
        CreateMotion(preFix + "Step_Forward_Long", kMotion_Z);
        CreateMotion(preFix + "Step_Right_Long", kMotion_X);
        CreateMotion(preFix + "Step_Back_Long", kMotion_Z);
        CreateMotion(preFix + "Step_Left_Long", kMotion_X);

        CreateMotion(preFix + "135_Turn_Left", kMotion_XZR, kMotion_R, 32);
        CreateMotion(preFix + "135_Turn_Right", kMotion_XZR, kMotion_R, 32);

        CreateMotion(preFix + "Run_Forward_Combat", kMotion_Z, kMotion_XZR, -1, 0, true);
        CreateMotion(preFix + "Redirect_push_back");
        CreateMotion(preFix + "Redirect_Stumble_JK");

        CreateMotion(preFix + "Attack_Kick");
        CreateMotion(preFix + "Attack_Kick_01");
        CreateMotion(preFix + "Attack_Kick_02");
        CreateMotion(preFix + "Attack_Punch");
        CreateMotion(preFix + "Attack_Punch_01");
        CreateMotion(preFix + "Attack_Punch_02");


        String preFix1 = "TG_HitReaction/";
        CreateMotion(preFix1 + "HitReaction_Left");
        CreateMotion(preFix1 + "HitReaction_Right");
        CreateMotion(preFix1 + "HitReaction_Back_NoTurn");
        CreateMotion(preFix1 + "Generic_Hit_Reaction");

        CreateMotion(preFix1 + "Push_Reaction");
        CreateMotion(preFix1 + "Push_Reaction_From_Back");

        AddCounterMotions("TG_BM_Counter/");

        PostProcess();

        Print("************************************************************************************************");
        Print("Motion Process time-cost=" + String(time.systemTime - startTime) + " ms num-of-motions=" + motions.length + " memory-use=" + String(memoryUse/1024) + " KB");
        Print("************************************************************************************************");
    }

    void Stop()
    {
        motions.Clear();
    }

    Motion@ CreateMotion(const String&in name, int motionFlag = kMotion_XZR, int allowMotion = kMotion_XZR,  int endFrame = -1, int originFlag = 0, bool loop = false, bool cutRotation = false)
    {
        Motion@ motion = Motion();
        motion.name = name;
        motion.motionFlag = motionFlag;
        motion.originFlag = originFlag;
        motion.allowMotion = allowMotion;
        motion.cutRotation = cutRotation;
        motion.looped = loop;
        motion.endFrame = endFrame;
        motions.Push(motion);
        motion.Process();
        return motion;
    }

    Motion@ CreateCustomMotion(Motion@ refMotion, const String&in name)
    {
        Motion@ motion = Motion(refMotion);
        motion.name = name;
        motions.Push(motion);
        return motion;
    }

    void AddCounterMotions(const String&in counter_prefix)
    {
        CreateMotion(counter_prefix + "Counter_Arm_Back_01");
        CreateMotion(counter_prefix + "Counter_Arm_Back_02");
        CreateMotion(counter_prefix + "Counter_Arm_Back_03");
        CreateMotion(counter_prefix + "Counter_Arm_Back_05");
        CreateMotion(counter_prefix + "Counter_Arm_Back_06");

        CreateMotion(counter_prefix + "Counter_Arm_Back_Weak_01");
        CreateMotion(counter_prefix + "Counter_Arm_Back_Weak_02");
        CreateMotion(counter_prefix + "Counter_Arm_Back_Weak_03");

        CreateMotion(counter_prefix + "Counter_Arm_Front_01");
        CreateMotion(counter_prefix + "Counter_Arm_Front_02");
        CreateMotion(counter_prefix + "Counter_Arm_Front_03");
        CreateMotion(counter_prefix + "Counter_Arm_Front_04");
        CreateMotion(counter_prefix + "Counter_Arm_Front_05");
        CreateMotion(counter_prefix + "Counter_Arm_Front_06");
        CreateMotion(counter_prefix + "Counter_Arm_Front_07");
        CreateMotion(counter_prefix + "Counter_Arm_Front_08");
        CreateMotion(counter_prefix + "Counter_Arm_Front_09");
        CreateMotion(counter_prefix + "Counter_Arm_Front_10");
        CreateMotion(counter_prefix + "Counter_Arm_Front_13");
        CreateMotion(counter_prefix + "Counter_Arm_Front_14");

        CreateMotion(counter_prefix + "Counter_Arm_Front_Weak_02");
        CreateMotion(counter_prefix + "Counter_Arm_Front_Weak_03");
        CreateMotion(counter_prefix + "Counter_Arm_Front_Weak_04");

        CreateMotion(counter_prefix + "Counter_Leg_Back_01");
        CreateMotion(counter_prefix + "Counter_Leg_Back_02");
        CreateMotion(counter_prefix + "Counter_Leg_Back_03");
        CreateMotion(counter_prefix + "Counter_Leg_Back_04");
        CreateMotion(counter_prefix + "Counter_Leg_Back_05");

        CreateMotion(counter_prefix + "Counter_Leg_Back_Weak_01");
        CreateMotion(counter_prefix + "Counter_Leg_Back_Weak_03");

        CreateMotion(counter_prefix + "Counter_Leg_Front_01");
        CreateMotion(counter_prefix + "Counter_Leg_Front_02");
        CreateMotion(counter_prefix + "Counter_Leg_Front_03");
        CreateMotion(counter_prefix + "Counter_Leg_Front_04");
        CreateMotion(counter_prefix + "Counter_Leg_Front_05");
        CreateMotion(counter_prefix + "Counter_Leg_Front_06");
        CreateMotion(counter_prefix + "Counter_Leg_Front_07");
        CreateMotion(counter_prefix + "Counter_Leg_Front_08");
        CreateMotion(counter_prefix + "Counter_Leg_Front_09");

        CreateMotion(counter_prefix + "Counter_Leg_Front_Weak");
        CreateMotion(counter_prefix + "Counter_Leg_Front_Weak_01");
        CreateMotion(counter_prefix + "Counter_Leg_Front_Weak_02");
    }
};


MotionManager@ gMotionMgr = MotionManager();