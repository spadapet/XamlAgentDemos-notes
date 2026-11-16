using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;

[assembly: ThemeInfo(ResourceDictionaryLocation.None, ResourceDictionaryLocation.SourceAssembly)]
[assembly: XmlnsDefinition("http://schemas.contoso.com/ui/kit", "Contoso.UI.Kit")]
[assembly: XmlnsPrefix("http://schemas.contoso.com/ui/kit", "kit")]

namespace Contoso.UI.Kit;

/// <summary>A horizontal strip of avatar chips for a list of people.</summary>
public class PeopleStrip : ItemsControl
{
    static PeopleStrip()
    {
        DefaultStyleKeyProperty.OverrideMetadata(typeof(PeopleStrip), new FrameworkPropertyMetadata(typeof(PeopleStrip)));
    }
}

/// <summary>An elevated card with a hover sheen and an optional actions row.</summary>
public class ActionCard : ContentControl
{
    public static readonly DependencyProperty ActionsProperty =
        DependencyProperty.Register(nameof(Actions), typeof(object), typeof(ActionCard));

    public static readonly DependencyProperty HeaderProperty =
        DependencyProperty.Register(nameof(Header), typeof(string), typeof(ActionCard));

    static ActionCard()
    {
        DefaultStyleKeyProperty.OverrideMetadata(typeof(ActionCard), new FrameworkPropertyMetadata(typeof(ActionCard)));
    }

    public object? Actions
    {
        get => GetValue(ActionsProperty);
        set => SetValue(ActionsProperty, value);
    }

    public string? Header
    {
        get => (string?)GetValue(HeaderProperty);
        set => SetValue(HeaderProperty, value);
    }
}
