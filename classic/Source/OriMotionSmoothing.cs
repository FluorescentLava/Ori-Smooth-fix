using UnityEngine;
using System.Reflection;

// Interpolate render poses only; use the game's existing unsynchronized physics
// mode to prevent SyncFramesTest from modulating timeScale on each render frame.
public sealed class OriMotionSmoothing : MonoBehaviour
{
    public static bool Enabled = true;
    public static bool TrailSmoothingEnabled = true;
    public static bool MeshUploadOptimizationEnabled = true;
    private static OriMotionSmoothing Instance;
    private PhysicsLimitTest ConfiguredPhysicsLimiter;
    private GameplayCamera TrackedCamera;
    private SeinCharacter TrackedPlayer;
    private float FixedTime = float.NaN;
    private Vector3 PreviousCamera, CurrentCamera, PreviousPlayer, CurrentPlayer;
    private Quaternion PreviousRotation, CurrentRotation;
    private bool HaveHistory, Applied, HavePlayer;
    private Transform AppliedCamera, AppliedSprite;
    private Vector3 SavedCameraPosition, SavedSpriteLocalPosition;
    private Quaternion SavedCameraRotation;
    private UberGhostTrail[] PlayerTrails = new UberGhostTrail[0];
    private int[] TrailFrames = new int[0];
    private bool RenderingTrails;
    private bool ResetTrails;
    private OriMotionCameraHook CameraHook;
    private static readonly FieldInfo TrailPrevious = typeof(UberGhostTrail).GetField("m_previousPosition", BindingFlags.Instance | BindingFlags.NonPublic);
    private static readonly FieldInfo TrailLastSpawn = typeof(UberGhostTrail).GetField("m_lastSpawnPoint", BindingFlags.Instance | BindingFlags.NonPublic);
    private static readonly FieldInfo TrailDistance = typeof(UberGhostTrail).GetField("m_travelDistance", BindingFlags.Instance | BindingFlags.NonPublic);
    private static readonly FieldInfo TrailCenter = typeof(UberGhostTrail).GetField("m_previousCenterOffset", BindingFlags.Instance | BindingFlags.NonPublic);
    private static readonly FieldInfo PhysicsSynced = typeof(PhysicsLimitTest).GetField("m_synced", BindingFlags.Instance | BindingFlags.NonPublic);

    // Called by the three scoped hooks in the game's original trail code.
    // Non-player effects retain their original scheduling and arithmetic.
    public static int TrailStride(UberGhostTrailMeshUpdate mesh)
    {
        return TrailSmoothingEnabled && Instance != null && IsPlayerTrail(mesh.GhostTarget) ? 1 : 4;
    }

    public static bool CanReuseTrailMesh(UberGhostTrailMeshUpdate mesh)
    {
        return MeshUploadOptimizationEnabled && TrailSmoothingEnabled
            && Instance != null && IsPlayerTrail(mesh.GhostTarget);
    }

    private static bool IsPlayerTrail(UberGhostTrail trail)
    {
        SeinCharacter player = Game.Characters.Sein;
        return trail != null && player != null && trail.AnimatorTarget != null
            && trail.AnimatorTarget.transform.IsChildOf(player.transform)
            && trail.transform.IsChildOf(player.transform);
    }

    public static bool SkipTrailUpdate(UberGhostTrail trail)
    {
        if (!TrailSmoothingEnabled || Instance == null || !IsPlayerTrail(trail)) return false;
        for (int i = 0; i < Instance.PlayerTrails.Length; i++)
        {
            if (Instance.PlayerTrails[i] != trail) continue;
            if (Instance.TrailFrames[i] == Time.frameCount) return true;
            if (!Instance.RenderingTrails && Enabled && Instance.HaveHistory
                && Instance.CanSmooth(Instance.TrackedCamera)) return true;
            Instance.TrailFrames[i] = Time.frameCount;
            break;
        }
        return false;
    }

    public static void Install()
    {
        if (Instance == null && GameController.Instance != null)
            Instance = (OriMotionSmoothing)GameController.Instance.gameObject.AddComponent(typeof(OriMotionSmoothing));
    }

    private void Update()
    {
        if (Application.targetFrameRate != -1) Application.targetFrameRate = -1;
        if (QualitySettings.vSyncCount != 0) QualitySettings.vSyncCount = 0;
        PhysicsLimitTest limiter = PhysicsLimitTest.Instance;
        if (limiter != null && limiter != ConfiguredPhysicsLimiter)
        {
            // Native option 2 preserves the fixed simulation step and permits
            // up to two simulation steps per render frame. In the 2015 game,
            // the option disables the limiter but leaves its cached synced
            // flag unchanged. Clear that flag once so SyncFramesTest uses the
            // unsynchronized path and keeps the normal timeScale of 1.
            limiter.CurrentToggleOptionId = 2;
            PhysicsSynced.SetValue(limiter, false);
            ConfiguredPhysicsLimiter = limiter;
        }
    }

    private void OnDisable()
    {
        Restore();
        if (CameraHook != null)
        {
            CameraHook.Owner = null;
            Destroy(CameraHook);
            CameraHook = null;
        }
        HaveHistory = false;
    }

    private void AttachCameraHook(Camera camera)
    {
        if (CameraHook != null && CameraHook.GetComponent<Camera>() == camera) return;
        if (CameraHook != null)
        {
            CameraHook.Owner = null;
            Destroy(CameraHook);
        }
        // This Unity build has no global Camera rendering callbacks. Use the
        // equivalent messages on a component attached to the actual camera.
        CameraHook = (OriMotionCameraHook)camera.gameObject.AddComponent(typeof(OriMotionCameraHook));
        CameraHook.Owner = this;
    }

    private bool CanSmooth(GameplayCamera camera)
    {
        return camera != null && camera.Controller != null && camera.Camera != null
            && !camera.IsSuspended && GameController.Instance != null
            && !GameController.Instance.GameplaySuspended && !GameController.Instance.IsLoadingGame
            && GameStateMachine.Instance != null && (int)GameStateMachine.Instance.CurrentState == 3
            && Game.UI.Cameras.System != null && !Game.UI.Cameras.System.CrossFadeManager.IsCrossFading;
    }

    private static Vector3 PlayerPhysicsPosition(SeinCharacter player)
    {
        Rigidbody body = player.GetComponent<Rigidbody>();
        return body != null ? body.position : player.Position;
    }

    private void LateUpdate()
    {
        Restore();
        GameplayCamera camera = Game.UI.Cameras.Current;
        SeinCharacter player = Game.Characters.Sein;
        if (camera != null && camera.Camera != null) AttachCameraHook(camera.Camera);
        if (!CanSmooth(camera)) { HaveHistory = false; return; }
        bool hasPlayer = player != null && player.Active && !player.IsSuspended
            && player.PlatformBehaviour != null && player.PlatformBehaviour.Visuals != null
            && player.PlatformBehaviour.Visuals.Sprite != null;
        Vector3 cameraPosition = camera.Camera.transform.position;
        Quaternion cameraRotation = camera.Camera.transform.rotation;
        Vector3 playerPosition = hasPlayer ? PlayerPhysicsPosition(player) : Vector3.zero;
        if (!HaveHistory || TrackedCamera != camera || TrackedPlayer != player || HavePlayer != hasPlayer
            || Time.fixedTime < FixedTime)
        {
            ResetTrails = true;
            if (TrackedPlayer != player)
            {
                PlayerTrails = player != null ? player.GetComponentsInChildren<UberGhostTrail>(true) : new UberGhostTrail[0];
                TrailFrames = new int[PlayerTrails.Length];
                for (int i = 0; i < TrailFrames.Length; i++) TrailFrames[i] = -1;
            }
            PreviousCamera = CurrentCamera = cameraPosition;
            PreviousRotation = CurrentRotation = cameraRotation;
            PreviousPlayer = CurrentPlayer = playerPosition;
            FixedTime = Time.fixedTime;
            TrackedCamera = camera; TrackedPlayer = player; HavePlayer = hasPlayer; HaveHistory = true;
            return;
        }
        if (Time.fixedTime == FixedTime) return;
        PreviousCamera = CurrentCamera; CurrentCamera = cameraPosition;
        PreviousRotation = CurrentRotation; CurrentRotation = cameraRotation;
        PreviousPlayer = CurrentPlayer; CurrentPlayer = playerPosition;
        // Snap on discontinuities rather than dragging a teleport across the screen.
        if ((CurrentCamera - PreviousCamera).sqrMagnitude > 64f
            || (hasPlayer && (CurrentPlayer - PreviousPlayer).sqrMagnitude > 9f)
            || Time.fixedTime - FixedTime > Time.fixedDeltaTime * 1.5f)
        {
            PreviousCamera = CurrentCamera; PreviousRotation = CurrentRotation; PreviousPlayer = CurrentPlayer;
            ResetTrails = true;
        }
        FixedTime = Time.fixedTime;
    }

    public void BeforeRender(Camera camera)
    {
        if (!Enabled || Applied || !HaveHistory || !CanSmooth(TrackedCamera) || camera != TrackedCamera.Camera) return;
        float alpha = Mathf.Clamp01((Time.time - FixedTime) / Time.fixedDeltaTime);
        AppliedCamera = camera.transform;
        SavedCameraPosition = AppliedCamera.position; SavedCameraRotation = AppliedCamera.rotation;
        AppliedCamera.position = Vector3.Lerp(PreviousCamera, CurrentCamera, alpha);
        AppliedCamera.rotation = Quaternion.Slerp(PreviousRotation, CurrentRotation, alpha);
        if (HavePlayer && TrackedPlayer != null && TrackedPlayer.PlatformBehaviour.Visuals.Sprite != null)
        {
            AppliedSprite = TrackedPlayer.PlatformBehaviour.Visuals.Sprite.transform;
            // Refuse a root/physics transform: smoothing must only touch its visual descendant.
            if (AppliedSprite != TrackedPlayer.transform && AppliedSprite.IsChildOf(TrackedPlayer.transform)
                && AppliedSprite.GetComponent<Collider>() == null && AppliedSprite.GetComponent<Rigidbody>() == null)
            {
                SavedSpriteLocalPosition = AppliedSprite.localPosition;
                AppliedSprite.position += Vector3.Lerp(PreviousPlayer, CurrentPlayer, alpha) - TrackedPlayer.transform.position;
            }
            else AppliedSprite = null;
        }
        Applied = true;
        // Emit once per rendered gameplay frame while the sprite has its
        // interpolated pose. Detached ghost meshes keep world-space history.
        RenderingTrails = true;
        try
        {
            for (int i = 0; TrailSmoothingEnabled && i < PlayerTrails.Length; i++)
            {
                UberGhostTrail trail = PlayerTrails[i];
                if (trail != null && trail.enabled && trail.gameObject.activeInHierarchy)
                {
                    if (ResetTrails)
                    {
                        TrailPrevious.SetValue(trail, trail.transform.position);
                        TrailLastSpawn.SetValue(trail, trail.transform.position);
                        TrailDistance.SetValue(trail, 0f);
                        TrailCenter.SetValue(trail, Vector2.zero);
                    }
                    trail.Update();
                }
            }
            ResetTrails = false;
        }
        finally { RenderingTrails = false; }
    }

    public void AfterRender(Camera camera)
    {
        if (AppliedCamera != null && camera.transform == AppliedCamera) Restore();
    }

    private void Restore()
    {
        if (!Applied) return;
        if (AppliedCamera != null) { AppliedCamera.position = SavedCameraPosition; AppliedCamera.rotation = SavedCameraRotation; }
        if (AppliedSprite != null) AppliedSprite.localPosition = SavedSpriteLocalPosition;
        AppliedCamera = null; AppliedSprite = null; Applied = false;
    }
}

public sealed class OriMotionCameraHook : MonoBehaviour
{
    public OriMotionSmoothing Owner;
    private Camera RenderingCamera;

    private void Awake() { RenderingCamera = GetComponent<Camera>(); }
    private void OnPreCull() { if (Owner != null) Owner.BeforeRender(RenderingCamera); }
    private void OnPostRender() { if (Owner != null) Owner.AfterRender(RenderingCamera); }
    private void OnDisable() { if (Owner != null) Owner.AfterRender(RenderingCamera); }
}
