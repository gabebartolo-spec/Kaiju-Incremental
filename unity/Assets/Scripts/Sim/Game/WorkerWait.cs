// Generated from sim/worker_wait.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class WorkerWait : RefCounted
    {
        public static implicit operator WorkerWait(Variant v) => (WorkerWait)v.Obj;

        // The worker tasks started ahead of their use (CellPromoter.start, PieceParts.start), so each is
        // waited for exactly once: by its user, or at exit (QuitGame.release_sims_at_exit) when a run
        // drops it first. A task still running script code as the process quits crashes the exit.
        public static GArray<long> _open = new GArray<long>();

        public static long Add(long task)
        {
            _open.Append(task);
            return task;
        }
        // Waits for this task (once only; WorkerThreadPool forgets a task once waited for).

        public static void Wait(long task)
        {
            if (_open.Has(task))
            {
                _open.Erase(task);
                WorkerThreadPool.WaitForTaskCompletion(task);
            }
        }

        public static void WaitAll()
        {
            foreach (long task in _open)
            {
                WorkerThreadPool.WaitForTaskCompletion(task);
            }
            _open.Clear();
        }

        void _InitFields()
        {
        }
        public WorkerWait() { _InitFields(); }
    }
}
