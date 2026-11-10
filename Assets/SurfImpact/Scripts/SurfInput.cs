using UnityEngine;

namespace SurfImpact
{
    /// <summary>
    /// Keyboard + mouse/touch input. Mouse drag or touch drag steers like the
    /// browser game; keyboards use arrows/WASD.
    /// </summary>
    public class SurfInput
    {
        float _dragSteer;
        bool _dragging;
        Vector2 _dragStart;

        public void Tick()
        {
            if (Input.GetMouseButtonDown(0))
            {
                _dragging = true;
                _dragStart = Input.mousePosition;
            }
            if (Input.GetMouseButtonUp(0))
            {
                _dragging = false;
            }
            if (_dragging)
            {
                float dx = Input.mousePosition.x - _dragStart.x;
                _dragSteer = Mathf.Clamp(dx / 150f, -1f, 1f);
            }
            else if (Input.touchCount > 0)
            {
                Touch t = Input.GetTouch(0);
                if (t.phase == TouchPhase.Began) _dragStart = t.position;
                if (t.phase == TouchPhase.Moved || t.phase == TouchPhase.Stationary)
                {
                    float dx = t.position.x - _dragStart.x;
                    _dragSteer = Mathf.Clamp(dx / 120f, -1f, 1f);
                    _dragging = true;
                }
                if (t.phase == TouchPhase.Ended || t.phase == TouchPhase.Canceled)
                {
                    _dragSteer = 0f;
                    _dragging = false;
                }
            }
            else
            {
                _dragSteer = Mathf.MoveTowards(_dragSteer, 0f, Time.unscaledDeltaTime * 3f);
            }
        }

        public float Horizontal
        {
            get
            {
                float key = 0f;
                if (Input.GetKey(KeyCode.LeftArrow) || Input.GetKey(KeyCode.A)) key -= 1f;
                if (Input.GetKey(KeyCode.RightArrow) || Input.GetKey(KeyCode.D)) key += 1f;
                return Mathf.Clamp(key + _dragSteer, -1f, 1f);
            }
        }

        public float Vertical
        {
            get
            {
                float v = 0f;
                if (Input.GetKey(KeyCode.UpArrow) || Input.GetKey(KeyCode.W)) v += 1f;
                if (Input.GetKey(KeyCode.DownArrow) || Input.GetKey(KeyCode.S)) v -= 1f;
                return v;
            }
        }

        // Space is the in-game skill key; pause lives on Esc / P only.
        public bool PausePressed => Input.GetKeyDown(KeyCode.Escape) || Input.GetKeyDown(KeyCode.P);

        public bool BoostPressed => Input.GetKeyDown(KeyCode.F);

        public bool RestartPressed => Input.GetKeyDown(KeyCode.R);

        // Design doc keys: S shoots, J mounts a sleeping dinosaur, Space uses the skill.
        public bool ShootPressed => Input.GetKeyDown(KeyCode.S) || Input.GetKeyDown(KeyCode.DownArrow);
        public bool MountPressed => Input.GetKeyDown(KeyCode.J);
        public bool SkillPressed => Input.GetKeyDown(KeyCode.Space);

        public bool ConfirmPressed =>
            Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter) || Input.GetKeyDown(KeyCode.Space);

        public bool BackPressed => Input.GetKeyDown(KeyCode.Escape) || Input.GetKeyDown(KeyCode.Backspace);

        public bool MutePressed => Input.GetKeyDown(KeyCode.M);

        public bool AnyKeyPressed => Input.anyKeyDown;

        public bool SelectLeftPressed => Input.GetKeyDown(KeyCode.LeftArrow) || Input.GetKeyDown(KeyCode.A);
        public bool SelectRightPressed => Input.GetKeyDown(KeyCode.RightArrow) || Input.GetKeyDown(KeyCode.D);
        public bool SelectUpPressed => Input.GetKeyDown(KeyCode.UpArrow) || Input.GetKeyDown(KeyCode.W);
        public bool SelectDownPressed => Input.GetKeyDown(KeyCode.DownArrow) || Input.GetKeyDown(KeyCode.S);
        public bool NumberPressed(int n)
        {
            if (n < 1 || n > 9) return false;
            return Input.GetKeyDown(KeyCode.Alpha0 + n) || Input.GetKeyDown(KeyCode.Keypad0 + n);
        }
    }
}
