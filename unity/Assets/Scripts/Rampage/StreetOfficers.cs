using S = Kaiju.Sim;

// The street's police officers (scenes/street_life.gd add_cop, civilians and pose; street_steps.gd walk_cop): an
// officer is a person with an `officer` (Police.Officer) whose step Police takes; drawn and crushed with everyone
// else. Part of StreetPeople. No UnityEngine here: unity/SimTests compiles this file (PoliceCheck).
public sealed partial class StreetPeople
{
    // An officer joins the street (Police): drawn and crushed with everyone else.
    public void AddCop(Police.Officer o)
    {
        int i = AddPerson();
        Person p = people[i];
        p.pos = o.pos;
        p.heading = o.heading;
        p.outfit = COP;
        p.phase = o.phase;
        p.officer = o;
        people[i] = p;
    }

    // Everyone who is not an officer (Godot cop.count(0)).
    public int Civilians()
    {
        int n = 0;
        foreach (Person p in people)
            if (p.officer == null) n++;
        return n;
    }

    public int Officers() => people.Count - Civilians();

    // Officer i takes its police step, or leaves when its job is done (street_steps.gd walk_cop).
    void WalkCop(int i, double dt, S.Vector2 kaiju)
    {
        Person p = people[i];
        if (police.UpdateCop(p.officer, dt, kaiju))
        {
            Remove(i);
            return;
        }
        p.pos = p.officer.pos;
        p.heading = p.officer.heading;
        people[i] = p;
    }

    // An officer's pose: aiming while it holds, else a walk to its post or a run away.
    int OfficerPose(Person p)
    {
        if (p.officer.state == 1) return AIM;
        int stride = (int)(clock * RUN_HZ + p.phase * 2.0) % 2;
        return (p.officer.state == 2 ? RUN_A : WALK_A) + stride;
    }
}
