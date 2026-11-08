// Water runs on every tick of every rampage, and Unity's collector stops the game to scan the whole
// heap: garbage here cost 20 ms a tick in a player, against a 16.7 ms frame. .NET's collector hides
// that, so the replay's clock cannot catch it. This counts the bytes instead.
using System;
using Kaiju.Sim;

static class WaterCheck
{
    const int Side = 200;
    const int Steps = 100;
    // A call's own arguments and result list; one copied row or array is far over it.
    const long MostBytesPerStep = 4096;
    const double Inside = 7.0, Outside = 9.0;

    public static int Run()
    {
        WaterBasin basin = new WaterBasin(new Vector2(0.0, 0.0), 1.0, new Vector2i(Side, Side), 0.0);
        for (long k = 0; k < Side * Side; k++)
        {
            basin.floorY[k] = -1.0;
            basin.depth[k] = 1.0;
        }
        Rect2i all = new Rect2i(0, 0, Side, Side);
        RefCounted water = new KaijuWater();
        long before = GC.GetAllocatedBytesForCurrentThread();
        for (int s = 0; s < Steps; s++)
        {
            basin.Deepest(all);
            water.Call("step", basin.floorY, basin.depth, basin.body, basin.flow, basin.nx, all, 1L, 0.01, 0.99, 9.8, basin.cell, basin.rest, basin.open);
        }
        long perStep = (GC.GetAllocatedBytesForCurrentThread() - before) / Steps;

        // Deepest looks only inside its window.
        Rect2i window = new Rect2i(10, 20, 5, 5);
        basin.depth[20 * Side + 12] = Inside;
        basin.depth[30 * Side + 12] = Outside;
        double deepest = basin.Deepest(window);

        Console.WriteLine($"water: {perStep} bytes a step (at most {MostBytesPerStep}), deepest in window {deepest}");
        return (perStep > MostBytesPerStep ? 1 : 0) + (deepest != Inside ? 1 : 0);
    }
}
