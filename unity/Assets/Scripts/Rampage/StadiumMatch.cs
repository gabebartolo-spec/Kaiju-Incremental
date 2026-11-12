using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// A match on the stadium's pitch (scenes/stadium_match.gd, D-078): one sport per run (data/sports.json), picked
// from a presentation stream seeded off the run, two kits of players and a ball. Players spread loosely over the
// field and never stand still: the few nearest chase the ball, the nearest kicks it on, the rest drift about their
// spots. The moment the stadium loses its first chunk every player, after a moment's shock, runs for one of the
// tunnel mouths round the pitch away from the kaiju and is gone once inside; stomps crush them like any civilian.
// The stands hold the crowd (StadiumCrowd), who flee with them. StadiumView draws what this says.
// No UnityEngine here: unity/SimTests compiles this file (StadiumCheck). Presentation only: the sim and the
// economy never know any of them exist.
public sealed class StadiumMatch
{
    public static readonly string[] SKINS = { "e0b48e", "8d5a3b", "c58c5f" };
    // The poses a player uses: a jog while playing (walk a, walk b), the arms-up run when fleeing (run a, run b).
    public const int POSES = 4;
    const int RUN_POSES = 2;
    const double JOG_HZ = 5.0, RUN_HZ = 6.0;
    const double REACH = 0.6;  // how near a player must be to the ball to play it
    const double JOSTLE = 2.0;  // how fast (rad/s) the players at the ball circle it
    const double ROLL = 2.0, ROLL_DRAG = 1.5;  // the dropped ball's speed when the wall goes, and its drag (1/s)
    const double BALL_FADE = 0.3;  // seconds the ball takes to fade once the pitch is empty
    const double MOUTH_REACH = 0.15;  // a fleeing player is gone this near the far end of a tunnel mouth
    // Where the players start: the first by the ball, the rest loosely in their own half, inside the oval's edge.
    const double KICK_OFF = -0.04, OWN_HALF = -0.2, FAR = 0.85, OVAL = 0.9, PULL_MIN = 0.15, PULL_MAX = 0.45;
    const double PUFF_UP = 0.15, AWAY = 0.3, TURN_FLEE = 0.01, TURN_PLAY = 0.02, WANDER = 0.7;
    const double ON_BALL = 0.3, ROUND_BALL = 1.2, AT_FEET = 0.4;
    const double KICK_SPREAD = 0.8, PASS = 0.8, KICK_MIN = 0.3;
    const double ARC = 4.0, ARC_MAX = 1.5, ARC_PER_M = 0.25;

    public sealed class Player
    {
        public S.Vector2 pos, home, exit;
        public S.Vector2 heading = new S.Vector2(1, 0);
        public int team, skin;
        public double phase, pull = 0.5, wait;
    }

    public readonly S.GDict sport;
    public readonly List<Player> players = new List<Player>();
    public readonly StadiumCrowd crowd;
    // Inside each tunnel mouth round the pitch's edge: where a fleeing player runs to.
    public readonly List<S.Vector2> mouths = new List<S.Vector2>();
    public bool fleeing;
    // Running totals (the fixture and the stats line read them).
    public int escaped, killed, kicks;
    public S.Vector2 centre, half, ball;
    public double top, ballScale = 1.0, clock;

    readonly S.RampageSim sim;
    readonly int index;
    readonly long startAlive;
    readonly S.GDict cfg;
    readonly Action<S.Vector3> puff;
    readonly S.RandomNumberGenerator rng;
    S.Vector2 ballFrom, ballTo, roll;
    double ballT = 1.0, ballTime = 1.0, kickIn;

    // index: the stadium's building in sim.buildings. rng: the run's presentation stream. crowdMax: the graphics
    // preset's crowd_max (0: no crowd). forceSport: the sport to play instead of the seeded pick ("" = pick).
    public StadiumMatch(S.RampageSim sim, int index, Action<S.Vector3> puff, S.RandomNumberGenerator rng, int crowdMax, string forceSport = "")
    {
        this.sim = sim;
        this.index = index;
        this.puff = puff;
        this.rng = rng;
        S.GDict data = S.Content.Sports();
        cfg = data["pitch"];
        S.GArray<S.Variant> sports = data["sports"];
        sport = sports[rng.RandiRange(0, sports.Size() - 1)];
        foreach (S.Variant s in sports)
        {
            S.GDict row = s;
            if (S.Gd.Str(row["id"]) == forceSport) sport = row;
        }
        S.RampageSim.Building b = sim.buildings[index];
        startAlive = b.frame.aliveCount;
        centre = new S.Vector2(b.x, b.z);
        S.GArray<S.Variant> size = cfg["half"];
        half = new S.Vector2(S.Num.F(size[0]), S.Num.F(size[1]));
        top = S.Num.F(cfg["top"]);
        AddMouths();
        S.GArray<S.Variant> kits = sport["kits"];
        long perSide = S.Num.I(sport["per_side"]);
        S.Vector2 field = new S.Vector2(PitchProps.Field(sport, half)) / PitchProps.RES;
        for (int team = 0; team < kits.Size(); team++)
            for (int n = 0; n < perSide; n++) AddPlayer(team, n, field);
        ball = ballFrom = ballTo = centre;
        if (crowdMax > 0) crowd = new StadiumCrowd(sim, index, kits, rng, crowdMax) { puff = puff };
    }

    // Loose positions over the field, each side mostly in its own half; the first player starts by the ball in the
    // middle so the game opens with a kick.
    void AddPlayer(int team, int n, S.Vector2 field)
    {
        var p = new Player();
        double end = team == 0 ? -1.0 : 1.0;
        var at = new S.Vector2(KICK_OFF, 0.0);
        if (n + team > 0)
        {
            do at = new S.Vector2(end * rng.RandfRange(OWN_HALF, FAR), rng.RandfRange(-FAR, FAR));
            while (at.Length() > OVAL);
        }
        p.home = centre + at * field;
        p.pos = p.home;
        p.team = team;
        p.skin = (int)rng.RandiRange(0, SKINS.Length - 1);
        p.phase = rng.Randf();
        p.pull = rng.RandfRange(PULL_MIN, PULL_MAX);
        players.Add(p);
    }

    // Which way tunnel mouth k faces, out from the middle.
    public S.Vector2 MouthOut(int k) => S.Vector2.FromAngle((k + 0.5) * S.Gd.TAU / S.Num.I(cfg["mouths"]));

    // The mouth's box (across, up, deep), from data.
    public S.Vector3 MouthSize()
    {
        S.GArray<S.Variant> size = cfg["mouth"];
        return new S.Vector3(S.Num.F(size[0]), S.Num.F(size[1]), S.Num.F(size[2]));
    }

    // Dark tunnel mouths evenly round the pitch's edge; each leads a short way under the stands to the point a
    // fleeing player runs to.
    void AddMouths()
    {
        long count = S.Num.I(cfg["mouths"]);
        double deep = MouthSize().z;
        for (int k = 0; k < count; k++)
        {
            S.Vector2 dir = MouthOut(k);
            mouths.Add(centre + dir * half + dir * deep * 0.5);
        }
    }

    // Players still on the pitch.
    public int OnPitch() => players.Count;

    // Everyone within `radius` of `at` is crushed (one dust puff), players and fans where they are now. Returns
    // how many.
    public int Crush(S.Vector3 at, double radius)
    {
        int dead = killed;
        var c = new S.Vector2(at.x, at.z);
        bool puffed = false;
        for (int i = players.Count - 1; i >= 0; i--)
        {
            if (players[i].pos.DistanceTo(c) > radius) continue;
            if (!puffed)
            {
                puffed = true;
                puff?.Invoke(new S.Vector3(players[i].pos.x, top + PUFF_UP, players[i].pos.y));
            }
            players.RemoveAt(i);
            killed++;
        }
        dead = killed - dead;
        if (crowd != null) dead += crowd.Crush(at, radius);
        return dead;
    }

    public void Step(double delta)
    {
        clock += delta;
        if (!fleeing && sim.buildings[index].frame.aliveCount < startAlive) Panic();
        if (fleeing) Flee(delta);
        else Play(delta);
        crowd?.Step(delta);
    }

    // The wall gave: after a moment's shock each player makes for the nearest tunnel mouth that is not on the
    // kaiju's side.
    void Panic()
    {
        fleeing = true;
        S.Vector2 kaiju = sim.kaijuPos;
        crowd?.Panic();
        S.Vector2 toward = (kaiju - centre).Normalized();
        var safe = new List<S.Vector2>();
        foreach (S.Vector2 m in mouths)
            if ((m - centre).Normalized().Dot(toward) < AWAY) safe.Add(m);
        roll = (ballTo - ballFrom).Normalized() * ROLL;
        S.GArray<S.Variant> react = cfg["react"];
        foreach (Player p in players)
        {
            p.exit = safe[0];
            foreach (S.Vector2 m in safe)
                if (m.DistanceTo(p.pos) < p.exit.DistanceTo(p.pos)) p.exit = m;
            p.wait = rng.RandfRange(S.Num.F(react[0]), S.Num.F(react[1]));
        }
    }

    // In shock they keep drifting; then each runs for its mouth and is gone once inside.
    void Flee(double delta)
    {
        for (int i = players.Count - 1; i >= 0; i--)
        {
            Player p = players[i];
            p.wait -= delta;
            bool running = p.wait <= 0.0;
            S.Vector2 to = (running ? p.exit : Drift(p)) - p.pos;
            if (running && to.Length() < MOUTH_REACH)
            {
                players.RemoveAt(i);
                escaped++;
                continue;
            }
            double speed = S.Num.F(cfg[running ? "flee_speed" : "player_speed"]);
            if (to.Length() > TURN_FLEE) p.heading = to.Normalized();
            p.pos += p.heading * Math.Min(speed * delta, to.Length());
        }
        // The ball, dropped: it rolls to a stop, and fades out once the last player is gone.
        ball += roll * delta;
        roll *= Math.Max(0.0, 1.0 - ROLL_DRAG * delta);
        ballFrom = ball;
        ballTo = ball;
        ballT = 1.0;
        // Godot moves a (1, 1, 1) scale toward zero by delta / BALL_FADE along its length.
        if (players.Count == 0) ballScale = Math.Max(0.0, ballScale - delta / BALL_FADE / Math.Sqrt(3));
    }

    // A player's spot as the game sways: home, wandering a little, drawn toward the ball.
    S.Vector2 Drift(Player p)
    {
        double t = (clock * S.Num.F(cfg["drift_hz"]) + p.phase) * S.Gd.TAU;
        S.Vector2 wander = new S.Vector2(Math.Sin(t), Math.Cos(t * WANDER + p.phase)) * S.Num.F(cfg["drift"]);
        return (p.home + wander).Lerp(ballTo, p.pull);
    }

    // The players, nearest the ball's target first.
    List<Player> Order()
    {
        Player[] order = players.ToArray();
        S.GodotSort.Sort(order, order.Length, (a, b) => a.pos.DistanceTo(ballTo) < b.pos.DistanceTo(ballTo));
        return new List<Player>(order);
    }

    // The few nearest the ball chase it and the nearest plays it; the rest drift about.
    void Play(double delta)
    {
        ballT = Math.Min(1.0, ballT + delta / ballTime);
        ball = ballFrom.Lerp(ballTo, ballT);
        List<Player> order = Order();
        long chasers = S.Num.I(cfg["chasers"]);
        double step = S.Num.F(cfg["player_speed"]) * delta;
        double sprint = step * S.Num.F(cfg["sprint"]);
        for (int i = 0; i < order.Count; i++)
        {
            Player p = order[i];
            S.Vector2 goal = Drift(p);
            if (i < chasers)  // the nearest on the ball, the next jostling round it; never still
            {
                S.Vector2 round = S.Vector2.FromAngle(clock * JOSTLE + p.phase * S.Gd.TAU);
                goal = ballTo + round * (i == 0 ? REACH * ON_BALL : REACH * ROUND_BALL);
            }
            S.Vector2 to = goal - p.pos;
            if (to.Length() <= TURN_PLAY) continue;
            p.heading = to.Normalized();
            p.pos += p.heading * Math.Min(i < chasers ? sprint : step, to.Length());
        }
        HoldOrKick(order, delta);
    }

    // The nearest has the ball at their feet (never dead) and kicks it once the kick is due.
    void HoldOrKick(List<Player> order, double delta)
    {
        kickIn -= delta;
        if (order.Count == 0 || ballT < 1.0) return;
        Player holder = order[0];
        if (holder.pos.DistanceTo(ball) < REACH)
        {
            ballTo = holder.pos + holder.heading * REACH * AT_FEET;
            ballFrom = ballTo;
            ball = ballTo;
        }
        if (kickIn <= 0.0 && holder.pos.DistanceTo(ball) < REACH) Kick(holder);
    }

    void Kick(Player from)
    {
        var mates = new List<Player>();
        foreach (Player p in players)
            if (p.team == from.team && p != from) mates.Add(p);
        S.Vector2 target = centre + new S.Vector2(rng.RandfRange(-half.x, half.x) * KICK_SPREAD, rng.RandfRange(-half.y, half.y) * KICK_SPREAD);
        if (mates.Count > 0 && rng.Randf() < PASS) target = mates[(int)rng.RandiRange(0, mates.Count - 1)].pos;
        ballFrom = ball;
        ballTo = target;
        ballTime = Math.Max(KICK_MIN, ball.DistanceTo(target) / S.Num.F(cfg["kick_speed"]));
        ballT = 0.0;
        kicks++;
        S.GArray<S.Variant> every = cfg["kick_every"];
        kickIn = ballTime + rng.RandfRange(S.Num.F(every[0]), S.Num.F(every[1]));
    }

    // Which mesh a player is drawn with: (team, skin) then the pose, stepping at the jog's or the run's beat.
    public int Bucket(Player p)
    {
        int odd = (int)(clock * (fleeing ? RUN_HZ : JOG_HZ) + p.phase * 2.0) % 2;
        return (p.team * SKINS.Length + p.skin) * POSES + (fleeing ? RUN_POSES : 0) + odd;
    }

    // How high the kicked ball is over the grass.
    public double BallArc() => ARC * ballT * (1.0 - ballT) * Math.Min(ARC_MAX, ballFrom.DistanceTo(ballTo) * ARC_PER_M);
}
