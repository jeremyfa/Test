

class TextMenu
{
    UIElement@          root;
    Array<String>       texts;
    Array<Text@>        items;
    String              fontName;
    int                 fontSize;
    int                 selection = 0;
    Color               highLightColor = Color(1, 1, 0);
    Color               normalColor = Color(1, 0, 0);
    IntVector2          size = IntVector2(400, 100);
    uint                lastDirectionKeyTime = 0;

    TextMenu(const String& fName, int fSize)
    {
        fontName = fName;
        fontSize = fSize;
    }

    void Add()
    {
        if (root !is null)
            return;

        root = ui.root.CreateChild("UIElement");
        if (!engine.headless)
        {
            int height = graphics.height / 22;
            if (height > 64)
                height = 64;

            root.SetAlignment(HA_CENTER, VA_CENTER);
            root.SetPosition(0, -height * 2);
        }

        root.SetLayout(LM_VERTICAL, 8);
        root.SetFixedSize(size.x, size.y);

        for (uint i=0; i<texts.length; ++i)
        {
            AddText(texts[i]);
        }

        items[selection].color = highLightColor;
        lastDirectionKeyTime = time.systemTime;
        input.mouseVisible = true;
    }

    void Remove()
    {
        if (root is null)
            return;
        items.Clear();
        root.Remove();
        root = null;
        input.mouseVisible = false;
    }

    void AddText(const String& str)
    {
        Text@ text = root.CreateChild("Text");
        text.SetFont(cache.GetResource("Font", fontName), fontSize);
        text.text = str;
        text.color = normalColor;
        items.Push(text);
    }

    int Update(float dt)
    {
        int selIndex = selection;
        int inputDirection = gInput.GetDirectionPressed();
        if (inputDirection >= 0)
        {
            uint time_diff = time.systemTime - lastDirectionKeyTime;
            if (time_diff < 200)
                inputDirection = -1;
            else
                lastDirectionKeyTime = time.systemTime;
        }

        if (inputDirection == 0)
            selIndex --;
        if (inputDirection == 1)
            selIndex ++;
        if (inputDirection == 2)
            selIndex ++;
        if (inputDirection == 3)
            selIndex --;

        for (uint i=0; i<items.length; ++i)
        {
            if (items[i].hovering)
            {
                selIndex = int(i);
                break;
            }
        }

        if (selIndex >= int(items.length))
            selIndex = 0;
        if (selIndex < 0)
            selIndex = int(items.length) - 1;

        ChangeSelection(selIndex);
        return gInput.IsEnterPressed() ? selection : -1;
    }

    void ChangeSelection(int index)
    {
        if (selection == index)
            return;

        if (selection >= 0)
            items[selection].color = normalColor;

        selection = index;
        if (selection >= 0)
            items[selection].color = highLightColor;
    }
};