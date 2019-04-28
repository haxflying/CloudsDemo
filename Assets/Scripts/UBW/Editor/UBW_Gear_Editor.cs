using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(UBW_Gears))]
public class UBW_Gear_Editor : Editor {


    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        var gear = target as UBW_Gears;

        if(GUILayout.Button("Generate"))
        {
            gear.Generate();
        }

        if (GUILayout.Button("Refresh"))
        {
            gear.refresh();
        }

        if (GUILayout.Button("Clear"))
        {
            gear.Clear();
        }
    }
}
