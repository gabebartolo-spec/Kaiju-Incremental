// Generated from sim/convoy_route.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class ConvoyRoute : RefCounted
    {
        public static implicit operator ConvoyRoute(Variant v) => (ConvoyRoute)v.Obj;

        // A tank's route and drive state (Convoy, D-066): one per tank, by id, in Convoy.routes.
        // waypoints still to drive, the post last
        public GArray<Vector2> path = new GArray<Vector2>();
        // the road each leg runs along (-1: off the plan)
        public GArray<long> edges = new GArray<long>();
        public Vector2 goal = new Vector2(Gd.INF, Gd.INF);
        // its post is a reserve post, out of range
        public bool reserve = false;
        // the road it is on now
        public long edge = -1;
        public long column = -1;
        public double replanT = 0.0;
        public double stuckT = 0.0;
        // roads it was held up on: left out of its next plan
        public GDict skip = new GDict();
        public bool retreating = false;
        // an older tank it is backing up for
        public long giveTo = -1;
        public double yieldT = 0.0;
        // how long it has been giving way this time
        public double yieldAll = 0.0;
        // the way it last drove
        public Vector2 heading = Vector2.ZERO;
        // where its hull points: the pose the view draws
        public Vector2 front = Vector2.ZERO;
        // backing off with its front still to the kaiju
        public bool reversing = false;

        void _InitFields()
        {
        }
        public ConvoyRoute() { _InitFields(); }
    }
}
