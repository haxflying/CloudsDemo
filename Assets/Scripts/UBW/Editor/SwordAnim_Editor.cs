using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(SwordAnim))]
public class SwordAnim_Editor : Editor {

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        var anim = target as SwordAnim;

        if(GUILayout.Button("Init"))
        {
            anim.Init();
        }
        if (GUILayout.Button("Clear"))
        {
            anim.Clear();
        }

        if(GUILayout.Button("SetHeight"))
        {
            anim.SetHeight();
            EditorUtility.SetDirty(anim.data);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
        }
    }
}
