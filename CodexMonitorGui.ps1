[CmdletBinding()]
param(
    [Nullable[int]]$Port,
    [int]$RefreshSeconds = 5,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

$script:CodexMonitorScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($ScriptRoot) { $ScriptRoot } else { (Get-Location).Path }

. (Join-Path $script:CodexMonitorScriptRoot "CodexMonitor.Core.ps1")

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop
Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CodexMonitorShellInterop {
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern uint RegisterWindowMessage(string lpString);
}
'@ -ErrorAction Stop

$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Codex Monitor"
    Width="1140"
    Height="840"
    MinWidth="860"
    MinHeight="640"
    WindowStartupLocation="CenterScreen"
    Background="#FFF5F6F8"
    AllowsTransparency="False"
    UseLayoutRounding="True"
    SnapsToDevicePixels="True"
    TextOptions.TextFormattingMode="Display"
    TextOptions.TextRenderingMode="ClearType"
    TextOptions.TextHintingMode="Fixed">
    <Window.Resources>
        <LinearGradientBrush x:Key="WindowBackgroundBrush" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#FFF9FBFD" Offset="0" />
            <GradientStop Color="#FFF5F6F8" Offset="0.5" />
            <GradientStop Color="#FFF2F5F9" Offset="1" />
        </LinearGradientBrush>

        <Style x:Key="GlassCardStyle" TargetType="Border">
            <Setter Property="Background" Value="#F8FFFFFF" />
            <Setter Property="BorderBrush" Value="#D3DDE6EC" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="CornerRadius" Value="22" />
            <Setter Property="SnapsToDevicePixels" Value="True" />
        </Style>

        <Style x:Key="ToolbarChipStyle" TargetType="Border">
            <Setter Property="Padding" Value="12,6" />
            <Setter Property="Background" Value="#FCFFFFFF" />
            <Setter Property="BorderBrush" Value="#D5DEE6EC" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="CornerRadius" Value="13" />
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FFFFFFFF" />
                    <Setter Property="BorderBrush" Value="#FFCAD6DF" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="ToolbarMenuStyle" TargetType="Menu">
            <Setter Property="Background" Value="Transparent" />
            <Setter Property="BorderThickness" Value="0" />
            <Setter Property="Padding" Value="0" />
            <Setter Property="VerticalAlignment" Value="Center" />
        </Style>

        <Style x:Key="ToolbarMenuItemStyle" TargetType="MenuItem">
            <Setter Property="Foreground" Value="#FF314254" />
            <Setter Property="FontSize" Value="12" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Padding" Value="10,5" />
            <Setter Property="Margin" Value="0,0,6,0" />
            <Setter Property="Background" Value="Transparent" />
            <Setter Property="BorderBrush" Value="Transparent" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="MenuItem">
                        <Grid SnapsToDevicePixels="True">
                            <Border
                                Name="Chrome"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="9"
                                Padding="{TemplateBinding Padding}"
                                RenderTransformOrigin="0.5,0.5">
                                <Border.RenderTransform>
                                    <TranslateTransform Y="0" />
                                </Border.RenderTransform>
                                <ContentPresenter
                                    ContentSource="Header"
                                    RecognizesAccessKey="True"
                                    HorizontalAlignment="Center"
                                    VerticalAlignment="Center" />
                            </Border>

                            <Popup
                                x:Name="PART_Popup"
                                AllowsTransparency="True"
                                Focusable="False"
                                IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}"
                                Placement="Bottom"
                                PopupAnimation="Fade">
                                <Border
                                    Margin="0,8,0,0"
                                    Padding="6"
                                    Background="#FFFCFDFE"
                                    BorderBrush="#FFD8E1E9"
                                    BorderThickness="1"
                                    CornerRadius="12">
                                    <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle" />
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="Chrome" Property="Background" Value="#FFF7FAFC" />
                                <Setter TargetName="Chrome" Property="BorderBrush" Value="#FFD4DEE7" />
                            </Trigger>
                            <Trigger Property="IsSubmenuOpen" Value="True">
                                <Setter TargetName="Chrome" Property="Background" Value="#FFF7FAFC" />
                                <Setter TargetName="Chrome" Property="BorderBrush" Value="#FFD4DEE7" />
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Chrome" Property="Opacity" Value="0.42" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SectionPanelStyle" TargetType="Border" BasedOn="{StaticResource GlassCardStyle}">
            <Setter Property="Padding" Value="20" />
            <Setter Property="CornerRadius" Value="22" />
        </Style>

        <Style x:Key="InfoCardStyle" TargetType="Border" BasedOn="{StaticResource GlassCardStyle}">
            <Setter Property="Padding" Value="14" />
            <Setter Property="Background" Value="#FCFFFFFF" />
            <Setter Property="BorderBrush" Value="#FFD7E1E8" />
            <Setter Property="CornerRadius" Value="16" />
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FFFFFFFF" />
                    <Setter Property="BorderBrush" Value="#FFCAD6DF" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="PanelLabelStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#FF66778A" />
            <Setter Property="FontSize" Value="11" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="TextOptions.TextFormattingMode" Value="Display" />
        </Style>

        <Style x:Key="PanelSubtextStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#FF495A6C" />
            <Setter Property="FontSize" Value="12" />
            <Setter Property="TextWrapping" Value="Wrap" />
        </Style>

        <Style x:Key="SectionTitleStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#FF111827" />
            <Setter Property="FontSize" Value="17" />
            <Setter Property="FontWeight" Value="SemiBold" />
        </Style>

        <Style x:Key="SectionDescriptionStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#FF607084" />
            <Setter Property="FontSize" Value="11.5" />
            <Setter Property="TextWrapping" Value="Wrap" />
        </Style>

        <Style x:Key="BaseActionButtonStyle" TargetType="Button">
            <Setter Property="FontSize" Value="13" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Padding" Value="14,10" />
            <Setter Property="Margin" Value="0,0,0,8" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="SnapsToDevicePixels" Value="True" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border
                            Name="Chrome"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="12"
                            SnapsToDevicePixels="True">
                            <Grid>
                                <Border
                                    Name="InnerStroke"
                                    Margin="1"
                                    BorderBrush="#14FFFFFF"
                                    BorderThickness="1"
                                    CornerRadius="11"
                                    IsHitTestVisible="False" />
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}" />
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="InnerStroke" Property="BorderBrush" Value="#1FFFFFFF" />
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Chrome" Property="Opacity" Value="0.96" />
                                <Setter TargetName="InnerStroke" Property="BorderBrush" Value="#10FFFFFF" />
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Chrome" Property="Opacity" Value="0.42" />
                                <Setter TargetName="InnerStroke" Property="Opacity" Value="0.2" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PrimaryActionButtonStyle" TargetType="Button" BasedOn="{StaticResource BaseActionButtonStyle}">
            <Setter Property="Background" Value="#FF0A84FF" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="BorderBrush" Value="#1E0A84FF" />
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FF2490FF" />
                    <Setter Property="BorderBrush" Value="#332490FF" />
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#FF0077E6" />
                    <Setter Property="BorderBrush" Value="#330077E6" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SecondaryActionButtonStyle" TargetType="Button" BasedOn="{StaticResource BaseActionButtonStyle}">
            <Setter Property="Background" Value="#FFFBFCFD" />
            <Setter Property="Foreground" Value="#FF1F2937" />
            <Setter Property="BorderBrush" Value="#FFD6E0E8" />
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FFFFFFFF" />
                    <Setter Property="BorderBrush" Value="#FFC9D5DE" />
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#FFF4F8FB" />
                    <Setter Property="BorderBrush" Value="#FFC1CED8" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SubtleActionButtonStyle" TargetType="Button" BasedOn="{StaticResource BaseActionButtonStyle}">
            <Setter Property="Background" Value="#FFF8FAFC" />
            <Setter Property="Foreground" Value="#FF445567" />
            <Setter Property="BorderBrush" Value="#FFD6E0E8" />
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FFFCFDFE" />
                    <Setter Property="BorderBrush" Value="#FFCCD7E0" />
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#FFF2F6FA" />
                    <Setter Property="BorderBrush" Value="#FFC7D2DC" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="MetaBadgeBorderStyle" TargetType="Border">
            <Setter Property="Padding" Value="10,5" />
            <Setter Property="Background" Value="#FFFAFCFD" />
            <Setter Property="BorderBrush" Value="#FFD3DDE6" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="CornerRadius" Value="999" />
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FFFFFFFF" />
                    <Setter Property="BorderBrush" Value="#FFC9D5DE" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SurfaceLogContainerStyle" TargetType="Border" BasedOn="{StaticResource GlassCardStyle}">
            <Setter Property="Padding" Value="0" />
            <Setter Property="Background" Value="#FFFFFFFF" />
            <Setter Property="BorderBrush" Value="#FFD7E0E8" />
            <Setter Property="CornerRadius" Value="16" />
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="BorderBrush" Value="#FFCCD8E1" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SurfaceLogTextBoxStyle" TargetType="TextBox">
            <Setter Property="FontFamily" Value="Consolas" />
            <Setter Property="FontSize" Value="13" />
            <Setter Property="Background" Value="Transparent" />
            <Setter Property="Foreground" Value="#FF1F2937" />
            <Setter Property="BorderThickness" Value="0" />
            <Setter Property="Padding" Value="14,0,14,14" />
            <Setter Property="IsReadOnly" Value="True" />
            <Setter Property="AcceptsReturn" Value="True" />
            <Setter Property="VerticalScrollBarVisibility" Value="Auto" />
            <Setter Property="SnapsToDevicePixels" Value="True" />
            <Setter Property="TextOptions.TextFormattingMode" Value="Display" />
            <Setter Property="TextOptions.TextRenderingMode" Value="ClearType" />
            <Setter Property="TextOptions.TextHintingMode" Value="Fixed" />
        </Style>

        <Style x:Key="SurfaceLogCaptionStyle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#FF66778A" />
            <Setter Property="FontSize" Value="11" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Margin" Value="14,12,14,8" />
        </Style>

        <Style x:Key="PreferenceValueBorderStyle" TargetType="Border">
            <Setter Property="Background" Value="#FFFFFFFF" />
            <Setter Property="BorderBrush" Value="#FFD6E0E8" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="CornerRadius" Value="10" />
            <Setter Property="Padding" Value="10,8" />
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FFFCFDFE" />
                    <Setter Property="BorderBrush" Value="#FFCDD8E1" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="InlineFeedbackBorderStyle" TargetType="Border">
            <Setter Property="Background" Value="#FFF7FAFC" />
            <Setter Property="BorderBrush" Value="#FFD7E0E8" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="CornerRadius" Value="10" />
            <Setter Property="Padding" Value="10,8" />
        </Style>

        <Style x:Key="MiniActionButtonStyle" TargetType="Button" BasedOn="{StaticResource BaseActionButtonStyle}">
            <Setter Property="FontSize" Value="11.5" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Padding" Value="10,6" />
            <Setter Property="Margin" Value="0,0,0,0" />
            <Setter Property="Background" Value="#FFFBFCFD" />
            <Setter Property="Foreground" Value="#FF445567" />
            <Setter Property="BorderBrush" Value="#FFD6E0E8" />
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FFFFFFFF" />
                    <Setter Property="BorderBrush" Value="#FFC9D5DE" />
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#FFF4F8FB" />
                    <Setter Property="BorderBrush" Value="#FFC1CED8" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="PreferenceTextBoxStyle" TargetType="TextBox">
            <Setter Property="FontSize" Value="12.5" />
            <Setter Property="Padding" Value="10,8" />
            <Setter Property="Background" Value="#FFFFFFFF" />
            <Setter Property="Foreground" Value="#FF1F2937" />
            <Setter Property="BorderBrush" Value="#FFD6E0E8" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="TextWrapping" Value="NoWrap" />
            <Setter Property="CaretBrush" Value="#FF0A84FF" />
            <Setter Property="SelectionBrush" Value="#332490FF" />
            <Setter Property="SelectionOpacity" Value="1" />
            <Setter Property="SnapsToDevicePixels" Value="True" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border
                            Name="Chrome"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="10"
                            SnapsToDevicePixels="True">
                            <ScrollViewer
                                x:Name="PART_ContentHost"
                                Margin="{TemplateBinding Padding}" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Chrome" Property="Opacity" Value="0.5" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FFFCFDFE" />
                    <Setter Property="BorderBrush" Value="#FFCCD8E1" />
                </Trigger>
                <Trigger Property="IsKeyboardFocused" Value="True">
                    <Setter Property="Background" Value="#FFFFFFFF" />
                    <Setter Property="BorderBrush" Value="#FF7CB5F5" />
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>
    <DockPanel Margin="18" LastChildFill="True">
        <Border DockPanel.Dock="Top" Margin="0,0,0,12" Padding="14,10" Background="#F8FFFFFF" BorderBrush="#D2DCE5EB" BorderThickness="1" CornerRadius="16">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="Auto" />
                    <ColumnDefinition Width="Auto" />
                </Grid.ColumnDefinitions>

                <StackPanel VerticalAlignment="Center">
                    <TextBlock Text="Codex Monitor" Foreground="#FF14202B" FontSize="14" FontWeight="SemiBold" />
                    <TextBlock Name="ToolbarSubtitleTextBlock" Text="Monitor, dashboard, and push status" Foreground="#FF66778A" FontSize="11" Margin="0,2,0,0" />
                </StackPanel>

                <Menu Grid.Column="1" Margin="20,0,14,0" Style="{StaticResource ToolbarMenuStyle}">
                    <MenuItem Name="AppMenuItem" Header="App" Style="{StaticResource ToolbarMenuItemStyle}">
                        <MenuItem Name="MenuShowItem" Header="_Show Window" />
                        <MenuItem Name="MenuOpenDashboardItem" Header="_Open Dashboard" />
                        <Separator />
                        <MenuItem Name="MenuRefreshItem" Header="_Refresh" />
                        <Separator />
                        <MenuItem Name="LanguageMenuItem" Header="_Language">
                            <MenuItem Name="LanguageEnglishMenuItem" Header="English" IsCheckable="True" />
                            <MenuItem Name="LanguageChineseMenuItem" Header="Chinese" IsCheckable="True" />
                        </MenuItem>
                        <Separator />
                        <MenuItem Name="MenuTrayItem" Header="_Hide To Tray" />
                        <MenuItem Name="MenuExitItem" Header="E_xit" />
                    </MenuItem>
                    <MenuItem Name="OptionsMenuItem" Header="Options" Style="{StaticResource ToolbarMenuItemStyle}">
                        <MenuItem Name="StartupMenuItem" Header="Launch at Windows logon" IsCheckable="True" />
                        <Separator />
                        <MenuItem Name="TrayIconModeMenuItem" Header="Tray icon mode">
                            <MenuItem Name="TrayModeCombinedMenuItem" Header="Combined status" IsCheckable="True" />
                            <MenuItem Name="TrayModeMonitorMenuItem" Header="Monitor only" IsCheckable="True" />
                            <MenuItem Name="TrayModeDashboardMenuItem" Header="Dashboard only" IsCheckable="True" />
                        </MenuItem>
                    </MenuItem>
                    <MenuItem Name="HelpMenuItem" Header="Help" Style="{StaticResource ToolbarMenuItemStyle}">
                        <MenuItem Name="MenuDashboardUrlItem" Header="Dashboard: http://127.0.0.1:8754/" IsEnabled="False" />
                        <MenuItem Name="MenuStatusModeItem" Header="Tray mode: Combined status" IsEnabled="False" />
                    </MenuItem>
                </Menu>

                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Style="{StaticResource ToolbarChipStyle}" Margin="0,0,10,0">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Grid Width="14" Height="14">
                                <Ellipse Name="HeaderStatusHaloEllipse" Fill="#229CA3AF" />
                                <Ellipse Name="HeaderStatusEllipse" Width="8" Height="8" Fill="#FF9CA3AF" />
                            </Grid>
                            <TextBlock Name="HeaderStatusTextBlock" Margin="8,0,0,0" Foreground="#FF1F2937" FontSize="12" FontWeight="SemiBold" Text="Checking..." />
                        </StackPanel>
                    </Border>
                    <Border Name="RefreshHealthBorder" Style="{StaticResource ToolbarChipStyle}" Margin="0,0,10,0">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Grid Width="12" Height="12">
                                <Ellipse Name="RefreshHealthHaloEllipse" Fill="#229CA3AF" />
                                <Ellipse Name="RefreshHealthEllipse" Width="7" Height="7" Fill="#FF9CA3AF" />
                            </Grid>
                            <TextBlock Name="RefreshHealthTextBlock" Margin="8,0,0,0" Foreground="#FF526273" FontSize="11.5" FontWeight="SemiBold" Text="Refresh Healthy" />
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource ToolbarChipStyle}">
                        <TextBlock Name="DashboardUrlTextBlock" Foreground="#FF37506A" FontSize="12" FontWeight="SemiBold" />
                    </Border>
                </StackPanel>
            </Grid>
        </Border>

        <Border DockPanel.Dock="Bottom" Margin="0,12,0,0" Padding="14,10" Background="#F8FFFFFF" BorderBrush="#D2DCE5EB" BorderThickness="1" CornerRadius="14">
            <TextBlock Name="StatusBarTextBlock" Foreground="#FF425263" FontSize="13" Text="Ready." />
        </Border>

        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
            <StackPanel>
                <Border Padding="24" Style="{StaticResource GlassCardStyle}" CornerRadius="24">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="Auto" />
                        </Grid.ColumnDefinitions>
                        <StackPanel>
                            <TextBlock Text="Codex Monitor" Foreground="#FF111827" FontSize="30" FontWeight="SemiBold" />
                            <TextBlock Name="SubtitleTextBlock" Margin="0,8,0,0" Foreground="#FF536375" FontSize="13.5" Text="A quieter control surface for Codex completion monitoring, tray control, and iPhone push delivery." />
                            <TextBlock Name="TrayHintTextBlock" Margin="0,10,0,0" Foreground="#FF728196" FontSize="11.5" Text="Close or minimize to keep it running in the tray." />
                        </StackPanel>

                        <Border Grid.Column="1" Padding="18,14" Style="{StaticResource InfoCardStyle}" CornerRadius="18" VerticalAlignment="Top">
                            <StackPanel>
                                <TextBlock Name="NowWatchingLabelTextBlock" Text="Now Watching" Style="{StaticResource PanelLabelStyle}" />
                                <TextBlock Name="WatchingSummaryTextBlock" Margin="0,6,0,0" Foreground="#FF0F172A" FontSize="15" FontWeight="SemiBold" Text="Codex sessions" />
                                <TextBlock Name="WatchingPathTextBlock" Margin="0,6,0,0" Style="{StaticResource PanelSubtextStyle}" />
                            </StackPanel>
                        </Border>
                    </Grid>
                </Border>

                <Border Margin="0,18,0,0" Padding="16,14" Style="{StaticResource GlassCardStyle}" CornerRadius="20">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="1" />
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="1" />
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="1" />
                            <ColumnDefinition Width="*" />
                        </Grid.ColumnDefinitions>

                        <StackPanel Grid.Column="0">
                            <TextBlock Name="MonitorLabelTextBlock" Text="Monitor" Style="{StaticResource PanelLabelStyle}" />
                            <StackPanel Margin="0,10,0,0" Orientation="Horizontal" VerticalAlignment="Center">
                                <Grid Width="15" Height="15">
                                    <Ellipse Name="MonitorIndicatorHaloEllipse" Fill="#229CA3AF" />
                                    <Ellipse Name="MonitorIndicatorEllipse" Width="9" Height="9" Fill="#FF9CA3AF" />
                                </Grid>
                                <TextBlock Name="MonitorStatusTextBlock" Margin="10,0,0,0" Foreground="#FF0F172A" FontSize="22" FontWeight="SemiBold" />
                            </StackPanel>
                            <TextBlock Name="MonitorPidTextBlock" Margin="0,8,0,0" Style="{StaticResource PanelSubtextStyle}" />
                        </StackPanel>

                        <Border Grid.Column="1" Width="1" Margin="14,2" Background="#180F172A" />

                        <StackPanel Grid.Column="2" Margin="18,0,0,0">
                            <TextBlock Name="DashboardLabelTextBlock" Text="Dashboard" Style="{StaticResource PanelLabelStyle}" />
                            <StackPanel Margin="0,10,0,0" Orientation="Horizontal" VerticalAlignment="Center">
                                <Grid Width="15" Height="15">
                                    <Ellipse Name="DashboardIndicatorHaloEllipse" Fill="#229CA3AF" />
                                    <Ellipse Name="DashboardIndicatorEllipse" Width="9" Height="9" Fill="#FF9CA3AF" />
                                </Grid>
                                <TextBlock Name="DashboardStatusTextBlock" Margin="10,0,0,0" Foreground="#FF0F172A" FontSize="22" FontWeight="SemiBold" />
                            </StackPanel>
                            <TextBlock Name="DashboardPidTextBlock" Margin="0,8,0,0" Style="{StaticResource PanelSubtextStyle}" />
                        </StackPanel>

                        <Border Grid.Column="3" Width="1" Margin="14,2" Background="#180F172A" />

                        <StackPanel Grid.Column="4" Margin="18,0,0,0">
                            <TextBlock Name="CompletedTodayLabelTextBlock" Text="Completed Today" Style="{StaticResource PanelLabelStyle}" />
                            <TextBlock Name="CompletedCountTextBlock" Margin="0,10,0,0" Foreground="#FF0F172A" FontSize="24" FontWeight="SemiBold" />
                            <TextBlock Name="LastTurnTextBlock" Margin="0,8,0,0" Style="{StaticResource PanelSubtextStyle}" />
                        </StackPanel>

                        <Border Grid.Column="5" Width="1" Margin="14,2" Background="#180F172A" />

                        <StackPanel Grid.Column="6" Margin="18,0,0,0">
                            <TextBlock Name="NotificationsStatLabelTextBlock" Text="Notifications" Style="{StaticResource PanelLabelStyle}" />
                            <TextBlock Name="NotifiedCountTextBlock" Margin="0,10,0,0" Foreground="#FF0F172A" FontSize="24" FontWeight="SemiBold" />
                            <TextBlock Name="GeneratedAtTextBlock" Margin="0,8,0,0" Style="{StaticResource PanelSubtextStyle}" />
                        </StackPanel>
                    </Grid>
                </Border>

                <Grid Name="MainContentGrid" Margin="0,8,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="300" />
                        <ColumnDefinition Width="24" />
                        <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <Border Name="ActionsPanelBorder" Grid.Column="0" Padding="18" Style="{StaticResource SectionPanelStyle}">
                        <StackPanel>
                            <TextBlock Name="PreferencesTitleTextBlock" Text="Preferences" Style="{StaticResource SectionTitleStyle}" />
                            <TextBlock Name="PreferencesDescriptionTextBlock" Margin="0,6,0,16" Text="Keep service controls close, then tune how the monitor behaves." Style="{StaticResource SectionDescriptionStyle}" />

                            <TextBlock Name="ServicesLabelTextBlock" Text="Services" Style="{StaticResource PanelLabelStyle}" Margin="0,0,0,8" />
                            <Button Name="StartButton" Style="{StaticResource PrimaryActionButtonStyle}" Margin="0,0,0,10" Content="Start Monitor + Dashboard" />
                            <Button Name="StopButton" Style="{StaticResource SecondaryActionButtonStyle}" Content="Stop Monitor + Dashboard" />
                            <Button Name="RestartButton" Style="{StaticResource SecondaryActionButtonStyle}" Margin="0,0,0,14" Content="Restart Services" />

                            <TextBlock Name="UtilitiesLabelTextBlock" Text="Utilities" Style="{StaticResource PanelLabelStyle}" Margin="0,0,0,8" />
                            <Button Name="OpenButton" Style="{StaticResource SecondaryActionButtonStyle}" Content="Open Dashboard" />
                            <Button Name="TestButton" Style="{StaticResource SecondaryActionButtonStyle}" Content="Send Test Notification" />
                            <Button Name="RefreshButton" Margin="0,4,0,0" Style="{StaticResource SubtleActionButtonStyle}" Content="Refresh Now" />

                            <Border Margin="0,18,0,14" Height="1" Background="#180F172A" />

                            <Border Margin="0,0,0,0" Style="{StaticResource InfoCardStyle}">
                                <StackPanel>
                                    <TextBlock Name="NotificationsTitleTextBlock" Text="Notifications" Style="{StaticResource SectionTitleStyle}" />
                                    <TextBlock Name="NotificationsDescriptionTextBlock" Margin="0,8,0,0" Style="{StaticResource SectionDescriptionStyle}" Text="These values control where delivery goes and which local dashboard port the app uses." />

                                    <TextBlock Name="BarkUrlLabelTextBlock" Text="Bark URL" Style="{StaticResource PanelLabelStyle}" Margin="0,14,0,6" />
                                    <TextBox
                                        Name="BarkUrlTextBox"
                                        Style="{StaticResource PreferenceTextBoxStyle}"
                                        TextWrapping="NoWrap" />

                                    <TextBlock Name="DashboardPortLabelTextBlock" Text="Dashboard Port" Style="{StaticResource PanelLabelStyle}" Margin="0,12,0,6" />
                                    <TextBox
                                        Name="DashboardPortTextBox"
                                        Style="{StaticResource PreferenceTextBoxStyle}"
                                        TextWrapping="NoWrap" />

                                    <Button Name="SaveSettingsButton" Margin="0,12,0,0" Style="{StaticResource SecondaryActionButtonStyle}" Content="Save Notification Settings" />

                                    <Border Name="SettingsFeedbackBorder" Margin="0,10,0,0" Style="{StaticResource InlineFeedbackBorderStyle}">
                                        <TextBlock Name="SettingsFeedbackTextBlock" Foreground="#FF556577" FontSize="12" Text="Changes save into the local config files immediately." TextWrapping="Wrap" />
                                    </Border>
                                </StackPanel>
                            </Border>

                            <Border Margin="0,14,0,0" Style="{StaticResource InfoCardStyle}">
                                <StackPanel>
                                    <TextBlock Name="BehaviorTitleTextBlock" Text="Behavior" Style="{StaticResource SectionTitleStyle}" />
                                    <TextBlock Name="BehaviorDescriptionTextBlock" Margin="0,8,0,0" Style="{StaticResource SectionDescriptionStyle}" Text="Tray mode and startup still live in the menu for now, but their live state is summarized here." />

                                    <TextBlock Name="StartupLabelTextBlock" Text="Startup" Style="{StaticResource PanelLabelStyle}" Margin="0,14,0,6" />
                                    <Border Style="{StaticResource PreferenceValueBorderStyle}">
                                        <TextBlock Name="StartupPreferenceValueTextBlock" Foreground="#FF1F2937" FontSize="12.5" />
                                    </Border>

                                    <TextBlock Name="TrayModeLabelTextBlock" Text="Tray Mode" Style="{StaticResource PanelLabelStyle}" Margin="0,12,0,6" />
                                    <Border Style="{StaticResource PreferenceValueBorderStyle}">
                                        <TextBlock Name="TrayModePreferenceValueTextBlock" Foreground="#FF1F2937" FontSize="12.5" />
                                    </Border>

                                    <TextBlock Name="SettingsSummaryTextBlock" Margin="0,12,0,0" Style="{StaticResource PanelSubtextStyle}" Text="Use the Options menu or tray menu to change startup and tray icon behavior." />
                                </StackPanel>
                            </Border>

                            <Border Margin="0,14,0,0" Style="{StaticResource InfoCardStyle}">
                                <StackPanel>
                                    <TextBlock Name="NotesTitleTextBlock" Text="Notes" Style="{StaticResource SectionTitleStyle}" />
                                    <TextBlock Name="ActionNotesTextBlock" Margin="0,8,0,0" Style="{StaticResource PanelSubtextStyle}" Text="Buttons disable themselves when an action is not useful." />
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Border>

                    <Border Name="DetailsPanelBorder" Grid.Column="2" Padding="20" Style="{StaticResource SectionPanelStyle}">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto" />
                                <RowDefinition Height="Auto" />
                                <RowDefinition Height="280" />
                                <RowDefinition Height="18" />
                                <RowDefinition Height="Auto" />
                                <RowDefinition Height="Auto" />
                                <RowDefinition Height="150" />
                            </Grid.RowDefinitions>

                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*" />
                                    <ColumnDefinition Width="Auto" />
                                </Grid.ColumnDefinitions>
                                <StackPanel>
                                    <TextBlock Name="ActivityTitleTextBlock" Text="Activity" Foreground="#FF111827" FontSize="19" FontWeight="SemiBold" />
                                    <TextBlock Name="ActivityDescriptionTextBlock" Margin="0,4,0,0" Text="Live session output and delivery state." Style="{StaticResource SectionDescriptionStyle}" />
                                </StackPanel>
                                <Border Grid.Column="1" Name="MetaBadgeBorder" Style="{StaticResource MetaBadgeBorderStyle}" VerticalAlignment="Top">
                                    <TextBlock Name="MetaBadgeTextBlock" Foreground="#FF475569" FontSize="11" FontWeight="SemiBold" Text="Idle" />
                                </Border>
                            </Grid>

                            <TextBlock Grid.Row="1" Name="MetaTextBlock" Margin="0,10,0,14" Foreground="#FF607084" FontSize="11.5" TextWrapping="Wrap" />
                            <Border Grid.Row="2" Style="{StaticResource SurfaceLogContainerStyle}">
                                <DockPanel LastChildFill="True">
                                    <Grid DockPanel.Dock="Top" Margin="14,12,14,8">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*" />
                                            <ColumnDefinition Width="Auto" />
                                        </Grid.ColumnDefinitions>
                                        <StackPanel>
                                            <TextBlock Name="RecentLogTitleTextBlock" Text="Recent Log Lines" Foreground="#FF66778A" FontSize="11" FontWeight="SemiBold" />
                                            <TextBlock Name="LogSummaryTextBlock" Margin="0,4,0,0" Foreground="#FF445567" FontSize="12" Text="Waiting for log summary..." />
                                        </StackPanel>
                                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Top">
                                            <Button Name="ClearRebuildButton" Style="{StaticResource MiniActionButtonStyle}" Margin="0,0,8,0" Content="Clear + Rebuild" />
                                            <Button Name="CopyLogButton" Style="{StaticResource MiniActionButtonStyle}" Margin="0,0,8,0" Content="Copy Log" />
                                            <Button Name="OpenLogButton" Style="{StaticResource MiniActionButtonStyle}" Content="Open File" />
                                        </StackPanel>
                                    </Grid>
                                    <TextBox
                                        Name="LogTextBox"
                                        Style="{StaticResource SurfaceLogTextBoxStyle}"
                                        TextWrapping="NoWrap"
                                        HorizontalScrollBarVisibility="Auto" />
                                </DockPanel>
                            </Border>

                            <Border Grid.Row="3" Height="1" Background="#180F172A" VerticalAlignment="Center" />
                            <TextBlock Grid.Row="4" Name="SystemNotesTitleTextBlock" Text="System Notes" Foreground="#FF0F172A" FontSize="17" FontWeight="SemiBold" />
                            <Grid Grid.Row="5" Margin="0,6,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*" />
                                    <ColumnDefinition Width="Auto" />
                                </Grid.ColumnDefinitions>
                                <TextBlock Name="ErrorSummaryTextBlock" Foreground="#FF536375" FontSize="12" TextWrapping="Wrap" Text="No errors yet." />
                                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Top">
                                    <Button Name="CopyNotesButton" Style="{StaticResource MiniActionButtonStyle}" Margin="0,0,8,0" Content="Copy Notes" />
                                    <Button Name="OpenStateButton" Style="{StaticResource MiniActionButtonStyle}" Content="Open State" />
                                </StackPanel>
                            </Grid>
                            <Border Grid.Row="6" Name="ErrorDetailsBorder" Style="{StaticResource SurfaceLogContainerStyle}" Background="#FFFCFDFE" BorderBrush="#FFD8E1E9">
                                <DockPanel LastChildFill="True">
                                    <TextBlock DockPanel.Dock="Top" Name="LatestErrorPayloadTextBlock" Text="Latest Error Payload" Style="{StaticResource SurfaceLogCaptionStyle}" />
                                    <TextBox
                                        Name="ErrorDetailsTextBox"
                                        Style="{StaticResource SurfaceLogTextBoxStyle}"
                                        FontSize="13"
                                        Foreground="#FF516071"
                                        TextWrapping="Wrap"
                                        HorizontalScrollBarVisibility="Disabled"
                                        Text="Everything looks healthy." />
                                </DockPanel>
                            </Border>
                        </Grid>
                    </Border>
                </Grid>
            </StackPanel>
        </ScrollViewer>
    </DockPanel>
</Window>
'@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader)

if ($CheckOnly) {
    "GUI XAML loaded successfully."
    exit 0
}

$controls = @{
    Subtitle = $window.FindName("SubtitleTextBlock")
    ToolbarSubtitle = $window.FindName("ToolbarSubtitleTextBlock")
    TrayHint = $window.FindName("TrayHintTextBlock")
    NowWatchingLabel = $window.FindName("NowWatchingLabelTextBlock")
    DashboardUrl = $window.FindName("DashboardUrlTextBlock")
    HeaderStatus = $window.FindName("HeaderStatusTextBlock")
    HeaderStatusEllipse = $window.FindName("HeaderStatusEllipse")
    HeaderStatusHalo = $window.FindName("HeaderStatusHaloEllipse")
    RefreshHealthText = $window.FindName("RefreshHealthTextBlock")
    RefreshHealthBorder = $window.FindName("RefreshHealthBorder")
    RefreshHealthEllipse = $window.FindName("RefreshHealthEllipse")
    RefreshHealthHalo = $window.FindName("RefreshHealthHaloEllipse")
    WatchingSummary = $window.FindName("WatchingSummaryTextBlock")
    WatchingPath = $window.FindName("WatchingPathTextBlock")
    MonitorLabel = $window.FindName("MonitorLabelTextBlock")
    MonitorStatus = $window.FindName("MonitorStatusTextBlock")
    MonitorIndicator = $window.FindName("MonitorIndicatorEllipse")
    MonitorIndicatorHalo = $window.FindName("MonitorIndicatorHaloEllipse")
    MonitorPid = $window.FindName("MonitorPidTextBlock")
    DashboardLabel = $window.FindName("DashboardLabelTextBlock")
    DashboardStatus = $window.FindName("DashboardStatusTextBlock")
    DashboardIndicator = $window.FindName("DashboardIndicatorEllipse")
    DashboardIndicatorHalo = $window.FindName("DashboardIndicatorHaloEllipse")
    DashboardPid = $window.FindName("DashboardPidTextBlock")
    CompletedTodayLabel = $window.FindName("CompletedTodayLabelTextBlock")
    CompletedCount = $window.FindName("CompletedCountTextBlock")
    LastTurn = $window.FindName("LastTurnTextBlock")
    NotificationsStatLabel = $window.FindName("NotificationsStatLabelTextBlock")
    NotifiedCount = $window.FindName("NotifiedCountTextBlock")
    GeneratedAt = $window.FindName("GeneratedAtTextBlock")
    Meta = $window.FindName("MetaTextBlock")
    MetaBadge = $window.FindName("MetaBadgeTextBlock")
    MetaBadgeBorder = $window.FindName("MetaBadgeBorder")
    PreferencesTitle = $window.FindName("PreferencesTitleTextBlock")
    PreferencesDescription = $window.FindName("PreferencesDescriptionTextBlock")
    ServicesLabel = $window.FindName("ServicesLabelTextBlock")
    UtilitiesLabel = $window.FindName("UtilitiesLabelTextBlock")
    NotificationsTitle = $window.FindName("NotificationsTitleTextBlock")
    NotificationsDescription = $window.FindName("NotificationsDescriptionTextBlock")
    BarkUrlLabel = $window.FindName("BarkUrlLabelTextBlock")
    DashboardPortLabel = $window.FindName("DashboardPortLabelTextBlock")
    BehaviorTitle = $window.FindName("BehaviorTitleTextBlock")
    BehaviorDescription = $window.FindName("BehaviorDescriptionTextBlock")
    StartupLabel = $window.FindName("StartupLabelTextBlock")
    TrayModeLabel = $window.FindName("TrayModeLabelTextBlock")
    NotesTitle = $window.FindName("NotesTitleTextBlock")
    ActivityTitle = $window.FindName("ActivityTitleTextBlock")
    ActivityDescription = $window.FindName("ActivityDescriptionTextBlock")
    RecentLogTitle = $window.FindName("RecentLogTitleTextBlock")
    SystemNotesTitle = $window.FindName("SystemNotesTitleTextBlock")
    LatestErrorPayloadTitle = $window.FindName("LatestErrorPayloadTextBlock")
    LogSummary = $window.FindName("LogSummaryTextBlock")
    Log = $window.FindName("LogTextBox")
    ClearRebuildButton = $window.FindName("ClearRebuildButton")
    CopyLogButton = $window.FindName("CopyLogButton")
    OpenLogButton = $window.FindName("OpenLogButton")
    StatusBar = $window.FindName("StatusBarTextBlock")
    SettingsSummary = $window.FindName("SettingsSummaryTextBlock")
    StartupPreferenceValue = $window.FindName("StartupPreferenceValueTextBlock")
    TrayModePreferenceValue = $window.FindName("TrayModePreferenceValueTextBlock")
    ActionNotes = $window.FindName("ActionNotesTextBlock")
    BarkUrlTextBox = $window.FindName("BarkUrlTextBox")
    DashboardPortTextBox = $window.FindName("DashboardPortTextBox")
    SaveSettingsButton = $window.FindName("SaveSettingsButton")
    SettingsFeedbackBorder = $window.FindName("SettingsFeedbackBorder")
    SettingsFeedbackText = $window.FindName("SettingsFeedbackTextBlock")
    ErrorSummary = $window.FindName("ErrorSummaryTextBlock")
    ErrorDetails = $window.FindName("ErrorDetailsTextBox")
    ErrorDetailsBorder = $window.FindName("ErrorDetailsBorder")
    CopyNotesButton = $window.FindName("CopyNotesButton")
    OpenStateButton = $window.FindName("OpenStateButton")
    StartButton = $window.FindName("StartButton")
    StopButton = $window.FindName("StopButton")
    RestartButton = $window.FindName("RestartButton")
    OpenButton = $window.FindName("OpenButton")
    TestButton = $window.FindName("TestButton")
    RefreshButton = $window.FindName("RefreshButton")
    MainContentGrid = $window.FindName("MainContentGrid")
    ActionsPanel = $window.FindName("ActionsPanelBorder")
    DetailsPanel = $window.FindName("DetailsPanelBorder")
    StartupMenuItem = $window.FindName("StartupMenuItem")
    TrayModeCombinedMenuItem = $window.FindName("TrayModeCombinedMenuItem")
    TrayModeMonitorMenuItem = $window.FindName("TrayModeMonitorMenuItem")
    TrayModeDashboardMenuItem = $window.FindName("TrayModeDashboardMenuItem")
    AppMenuItem = $window.FindName("AppMenuItem")
    OptionsMenuItem = $window.FindName("OptionsMenuItem")
    HelpMenuItem = $window.FindName("HelpMenuItem")
    TrayIconModeMenuItem = $window.FindName("TrayIconModeMenuItem")
    LanguageMenuItem = $window.FindName("LanguageMenuItem")
    LanguageEnglishMenuItem = $window.FindName("LanguageEnglishMenuItem")
    LanguageChineseMenuItem = $window.FindName("LanguageChineseMenuItem")
    MenuShowItem = $window.FindName("MenuShowItem")
    MenuOpenDashboardItem = $window.FindName("MenuOpenDashboardItem")
    MenuRefreshItem = $window.FindName("MenuRefreshItem")
    MenuTrayItem = $window.FindName("MenuTrayItem")
    MenuExitItem = $window.FindName("MenuExitItem")
    MenuDashboardUrlItem = $window.FindName("MenuDashboardUrlItem")
    MenuStatusModeItem = $window.FindName("MenuStatusModeItem")
}

$actionButtons = @(
    $controls.StartButton,
    $controls.StopButton,
    $controls.RestartButton,
    $controls.OpenButton,
    $controls.TestButton,
    $controls.RefreshButton,
    $controls.ClearRebuildButton,
    $controls.SaveSettingsButton
)

$script:UiBusy = $false
$script:AllowExit = $false
$script:LastStatus = $null
$script:LastErrorRecord = $null
$script:AutoRefreshFailureCount = 0
$script:AutoRefreshLastFailureAt = $null
$script:AutoRefreshLastDialogAt = $null
$script:SuppressStartupHandler = $false
$script:SuppressTrayModeHandler = $false
$script:SuppressLanguageHandler = $false
$script:TrayIconMode = "combined"
$script:CurrentPort = Resolve-CodexMonitorDashboardPort -Port $Port
$script:UiLanguage = "zh-CN"
$script:LocaleCache = @{}
$script:TaskbarCreatedMessage = [CodexMonitorShellInterop]::RegisterWindowMessage("TaskbarCreated")
$script:WindowSource = $null
$script:WindowMessageHook = $null
$script:AppTrayIcon = $null

$script:AutoRefreshWarningThreshold = 2
$script:AutoRefreshDialogThreshold = 4
$script:AutoRefreshDialogCooldownSeconds = [Math]::Max(($RefreshSeconds * 3), 15)

function New-StatusBrush {
    param([string]$Color)
    [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
}

function Resolve-AppTrayIcon {
    if ($script:AppTrayIcon) {
        return $script:AppTrayIcon
    }

    foreach ($candidate in @(
        (Join-Path $script:CodexMonitorScriptRoot "AppIcon.ico"),
        (Join-Path (Split-Path -Parent $script:CodexMonitorScriptRoot) "AppIcon.ico")
    )) {
        if (Test-Path -LiteralPath $candidate) {
            try {
                $script:AppTrayIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($candidate)
                if ($script:AppTrayIcon) {
                    return $script:AppTrayIcon
                }
            }
            catch {
            }

            try {
                $stream = [System.IO.File]::OpenRead($candidate)
                try {
                    $script:AppTrayIcon = [System.Drawing.Icon]::new($stream)
                }
                finally {
                    $stream.Dispose()
                }

                if ($script:AppTrayIcon) {
                    return $script:AppTrayIcon
                }
            }
            catch {
            }
        }
    }

    $script:AppTrayIcon = [System.Drawing.SystemIcons]::Application
    return $script:AppTrayIcon
}

function Get-LocalizedText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [object[]]$Args
    )

    if (-not $script:LocaleCache.ContainsKey($script:UiLanguage)) {
        $localePath = Join-Path $script:CodexMonitorScriptRoot ("locales\{0}.json" -f $script:UiLanguage)
        if (-not (Test-Path -LiteralPath $localePath)) {
            $localePath = Join-Path $script:CodexMonitorScriptRoot "locales\en-US.json"
        }

        $script:LocaleCache[$script:UiLanguage] = Read-CodexMonitorJsonFile -Path $localePath -Description "locale file"
    }

    $languageMap = $script:LocaleCache[$script:UiLanguage]
    $template = $Key
    if ($languageMap -is [System.Collections.IDictionary]) {
        if ($languageMap.Contains($Key)) {
            $template = [string]$languageMap[$Key]
        }
    }
    elseif ($null -ne $languageMap.PSObject.Properties[$Key]) {
        $template = [string]$languageMap.$Key
    }
    if ($Args -and $Args.Count -gt 0) {
        return [string]::Format($template, $Args)
    }
    return $template
}

function Set-UiStatusMessage {
    param([string]$Message)
    $controls.StatusBar.Text = $Message
}

function Update-LanguageMenuState {
    $script:SuppressLanguageHandler = $true
    $controls.LanguageEnglishMenuItem.IsChecked = ($script:UiLanguage -eq "en-US")
    $controls.LanguageChineseMenuItem.IsChecked = ($script:UiLanguage -eq "zh-CN")
    $script:SuppressLanguageHandler = $false
}

function Apply-UiLanguage {
    $controls.AppMenuItem.Header = Get-LocalizedText "App"
    $controls.OptionsMenuItem.Header = Get-LocalizedText "Options"
    $controls.HelpMenuItem.Header = Get-LocalizedText "Help"
    $controls.MenuShowItem.Header = Get-LocalizedText "ShowWindow"
    $controls.MenuOpenDashboardItem.Header = Get-LocalizedText "OpenDashboard"
    $controls.MenuRefreshItem.Header = Get-LocalizedText "Refresh"
    $controls.MenuTrayItem.Header = Get-LocalizedText "HideToTray"
    $controls.MenuExitItem.Header = Get-LocalizedText "Exit"
    $controls.LanguageMenuItem.Header = Get-LocalizedText "Language"
    $controls.LanguageEnglishMenuItem.Header = Get-LocalizedText "LanguageEnglish"
    $controls.LanguageChineseMenuItem.Header = Get-LocalizedText "LanguageChinese"
    $controls.StartupMenuItem.Header = Get-LocalizedText "LaunchAtLogon"
    $controls.TrayIconModeMenuItem.Header = Get-LocalizedText "TrayIconMode"
    $controls.TrayModeCombinedMenuItem.Header = Get-LocalizedText "CombinedStatus"
    $controls.TrayModeMonitorMenuItem.Header = Get-LocalizedText "MonitorOnly"
    $controls.TrayModeDashboardMenuItem.Header = Get-LocalizedText "DashboardOnly"
    $controls.ToolbarSubtitle.Text = Get-LocalizedText "HeaderSubtitle"
    $controls.StatusBar.Text = Get-LocalizedText "Ready"
    $controls.Subtitle.Text = Get-LocalizedText "HeroSubtitle"
    $controls.TrayHint.Text = Get-LocalizedText "TrayHintSafer"
    $controls.NowWatchingLabel.Text = Get-LocalizedText "NowWatching"
    $controls.WatchingSummary.Text = Get-LocalizedText "CodexSessions"
    $controls.MonitorLabel.Text = Get-LocalizedText "Monitor"
    $controls.DashboardLabel.Text = Get-LocalizedText "Dashboard"
    $controls.CompletedTodayLabel.Text = Get-LocalizedText "CompletedToday"
    $controls.NotificationsStatLabel.Text = Get-LocalizedText "Notifications"
    $controls.PreferencesTitle.Text = Get-LocalizedText "Preferences"
    $controls.PreferencesDescription.Text = Get-LocalizedText "PreferencesDescription"
    $controls.ServicesLabel.Text = Get-LocalizedText "Services"
    $controls.UtilitiesLabel.Text = Get-LocalizedText "Utilities"
    $controls.NotificationsTitle.Text = Get-LocalizedText "Notifications"
    $controls.NotificationsDescription.Text = Get-LocalizedText "NotificationsDescription"
    $controls.BarkUrlLabel.Text = Get-LocalizedText "BarkUrl"
    $controls.DashboardPortLabel.Text = Get-LocalizedText "DashboardPort"
    $controls.BehaviorTitle.Text = Get-LocalizedText "Behavior"
    $controls.BehaviorDescription.Text = Get-LocalizedText "BehaviorDescription"
    $controls.StartupLabel.Text = Get-LocalizedText "Startup"
    $controls.TrayModeLabel.Text = Get-LocalizedText "TrayMode"
    $controls.NotesTitle.Text = Get-LocalizedText "Notes"
    $controls.ActivityTitle.Text = Get-LocalizedText "Activity"
    $controls.ActivityDescription.Text = Get-LocalizedText "ActivityDescription"
    $controls.RecentLogTitle.Text = Get-LocalizedText "RecentLogLines"
    $controls.SystemNotesTitle.Text = Get-LocalizedText "SystemNotes"
    $controls.LatestErrorPayloadTitle.Text = Get-LocalizedText "LatestErrorPayload"
    $controls.SettingsFeedbackText.Text = Get-LocalizedText "SettingsSavedImmediately"
    if (-not $script:LastErrorRecord) {
        $controls.ErrorSummary.Text = Get-LocalizedText "NoErrorsYet"
        $controls.ErrorDetails.Text = Get-LocalizedText "EverythingHealthy"
    }

    $controls.StartButton.Content = Get-LocalizedText "StartMonitorDashboard"
    $controls.StopButton.Content = Get-LocalizedText "StopMonitorDashboard"
    $controls.RestartButton.Content = Get-LocalizedText "RestartServices"
    $controls.OpenButton.Content = Get-LocalizedText "OpenDashboard"
    $controls.TestButton.Content = Get-LocalizedText "SendTestNotification"
    $controls.RefreshButton.Content = Get-LocalizedText "RefreshNow"
    $controls.SaveSettingsButton.Content = Get-LocalizedText "SaveNotificationSettings"
    $controls.CopyLogButton.Content = Get-LocalizedText "CopyLog"
    $controls.OpenLogButton.Content = Get-LocalizedText "OpenFile"
    $controls.ClearRebuildButton.Content = Get-LocalizedText "ClearAndRebuild"
    $controls.CopyNotesButton.Content = Get-LocalizedText "CopyNotes"
    $controls.OpenStateButton.Content = Get-LocalizedText "OpenState"

    if ($script:TrayShowMenuItem) {
        $script:TrayShowMenuItem.Text = Get-LocalizedText "TrayShow"
        $script:TrayRefreshMenuItem.Text = Get-LocalizedText "TrayRefresh"
        $script:TrayStartMenuItem.Text = Get-LocalizedText "TrayStart"
        $script:TrayStopMenuItem.Text = Get-LocalizedText "TrayStop"
        $script:TrayRestartMenuItem.Text = Get-LocalizedText "TrayRestart"
        $script:TrayModeMenuItem.Text = Get-LocalizedText "TrayIconModeTitle"
        $script:TrayModeCombinedMenuItemTray.Text = Get-LocalizedText "CombinedStatus"
        $script:TrayModeMonitorMenuItemTray.Text = Get-LocalizedText "MonitorOnly"
        $script:TrayModeDashboardMenuItemTray.Text = Get-LocalizedText "DashboardOnly"
        $script:TrayExitMenuItem.Text = Get-LocalizedText "TrayExit"
    }

    Update-LanguageMenuState
    Update-StartupMenuState
    Update-UiButtonState
}

function Set-UiLanguage {
    param(
        [ValidateSet("en-US", "zh-CN")]
        [string]$Language
    )

    $script:UiLanguage = $Language
    Apply-UiLanguage
}

function Set-ClipboardText {
    param(
        [string]$Text,
        [string]$SuccessMessage
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw "There is nothing to copy yet."
    }

    [System.Windows.Clipboard]::SetText($Text)
    Set-UiStatusMessage -Message $SuccessMessage
}

function Open-PathIfExists {
    param(
        [string]$Path,
        [string]$MissingMessage
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        throw $MissingMessage
    }

    Start-Process $Path | Out-Null
}

function Set-SettingsFeedback {
    param(
        [string]$Message,
        [ValidateSet("neutral", "success", "warning", "error", "progress")]
        [string]$Tone = "neutral"
    )

    $controls.SettingsFeedbackText.Text = $Message

    switch ($Tone) {
        "success" {
            $controls.SettingsFeedbackText.Foreground = New-StatusBrush "#FF216E3A"
            $controls.SettingsFeedbackBorder.Background = New-StatusBrush "#FFF4FBF6"
            $controls.SettingsFeedbackBorder.BorderBrush = New-StatusBrush "#FFD6ECDC"
        }
        "warning" {
            $controls.SettingsFeedbackText.Foreground = New-StatusBrush "#FF8A5607"
            $controls.SettingsFeedbackBorder.Background = New-StatusBrush "#FFFFFAF2"
            $controls.SettingsFeedbackBorder.BorderBrush = New-StatusBrush "#FFF3DFC0"
        }
        "error" {
            $controls.SettingsFeedbackText.Foreground = New-StatusBrush "#FF9A3412"
            $controls.SettingsFeedbackBorder.Background = New-StatusBrush "#FFFFFBF5"
            $controls.SettingsFeedbackBorder.BorderBrush = New-StatusBrush "#FFF6D9B8"
        }
        "progress" {
            $controls.SettingsFeedbackText.Foreground = New-StatusBrush "#FF37506A"
            $controls.SettingsFeedbackBorder.Background = New-StatusBrush "#FFF7FAFC"
            $controls.SettingsFeedbackBorder.BorderBrush = New-StatusBrush "#FFD7E0E8"
        }
        default {
            $controls.SettingsFeedbackText.Foreground = New-StatusBrush "#FF556577"
            $controls.SettingsFeedbackBorder.Background = New-StatusBrush "#FFF7FAFC"
            $controls.SettingsFeedbackBorder.BorderBrush = New-StatusBrush "#FFD7E0E8"
        }
    }
}

function Sync-UiSettingsFields {
    try {
        $settings = Get-CodexMonitorAppSettings
        $script:CurrentPort = [int]$settings.dashboardPort
        $controls.BarkUrlTextBox.Text = [string]$settings.barkUrl
        $controls.DashboardPortTextBox.Text = [string]$settings.dashboardPort
        if (-not $controls.StartupPreferenceValue.Text) { $controls.StartupPreferenceValue.Text = Get-LocalizedText "Checking" }
        if (-not $controls.TrayModePreferenceValue.Text) { $controls.TrayModePreferenceValue.Text = Get-TrayModeLabel }
        if (-not $controls.SettingsFeedbackText.Text) { Set-SettingsFeedback -Message (Get-LocalizedText "SettingsSavedImmediately") -Tone "neutral" }
    }
    catch {
        if ($controls.BarkUrlTextBox.Text -eq $null) { $controls.BarkUrlTextBox.Text = "" }
        if ($controls.DashboardPortTextBox.Text -eq $null) { $controls.DashboardPortTextBox.Text = [string]$script:CurrentPort }
        if ($controls.StartupPreferenceValue.Text -eq $null) { $controls.StartupPreferenceValue.Text = Get-LocalizedText "Unavailable" }
        if ($controls.TrayModePreferenceValue.Text -eq $null) { $controls.TrayModePreferenceValue.Text = Get-TrayModeLabel }
        if ($controls.SettingsFeedbackText.Text -eq $null) { Set-SettingsFeedback -Message (Get-LocalizedText "SettingsNotLoadedYet") -Tone "warning" }
    }
}

function Set-MetaBadgeVisual {
    param(
        [string]$Text,
        [string]$Foreground = "#FF475569",
        [string]$Background = "#F4F7FAFC",
        [string]$BorderBrush = "#FFDCE4EC"
    )

    $controls.MetaBadge.Text = $Text
    $controls.MetaBadge.Foreground = New-StatusBrush $Foreground
    $controls.MetaBadgeBorder.Background = New-StatusBrush $Background
    $controls.MetaBadgeBorder.BorderBrush = New-StatusBrush $BorderBrush
}

function Set-RefreshHealthVisual {
    param(
        [string]$Text,
        [string]$Foreground = "#FF526273",
        [string]$Background = "#FFFAFCFD",
        [string]$BorderBrush = "#FFD3DDE6",
        [string]$SolidColor = "#FF9CA3AF",
        [string]$HaloColor = "#229CA3AF"
    )

    $controls.RefreshHealthText.Text = $Text
    $controls.RefreshHealthText.Foreground = New-StatusBrush $Foreground
    $controls.RefreshHealthBorder.Background = New-StatusBrush $Background
    $controls.RefreshHealthBorder.BorderBrush = New-StatusBrush $BorderBrush
    Set-StatusIndicatorVisual -SolidIndicator $controls.RefreshHealthEllipse -HaloIndicator $controls.RefreshHealthHalo -SolidColor $SolidColor -HaloColor $HaloColor
}

function Set-UiErrorState {
    param([string]$Summary, [string]$Details)
    $controls.ErrorSummary.Text = if ($Summary) { $Summary } else { "No errors yet." }
    $controls.ErrorDetails.Text = if ($Details) { $Details } else { "Everything looks healthy." }

    $hasIssue = $Summary -and ($Summary -ne "No errors yet.")
    if ($hasIssue) {
        $controls.ErrorSummary.Foreground = New-StatusBrush "#FF9A3412"
        $controls.ErrorDetails.Foreground = New-StatusBrush "#FF8A3A13"
        $controls.ErrorDetailsBorder.Background = New-StatusBrush "#FFFFFBF5"
        $controls.ErrorDetailsBorder.BorderBrush = New-StatusBrush "#FFF6D9B8"
    }
    else {
        $controls.ErrorSummary.Foreground = New-StatusBrush "#FF64748B"
        $controls.ErrorDetails.Foreground = New-StatusBrush "#FF516071"
        $controls.ErrorDetailsBorder.Background = New-StatusBrush "#FFF9FBFD"
        $controls.ErrorDetailsBorder.BorderBrush = New-StatusBrush "#FFE4E9EF"
    }
}

function Show-UiDiagnosticError {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$ActionLabel,
        [switch]$SuppressDialog
    )

    $diagnostic = Get-CodexMonitorDiagnosticSummary -ErrorRecord $ErrorRecord -ActionLabel $ActionLabel -Port $script:CurrentPort
    $details = Format-UiExceptionDetails -ErrorRecord $ErrorRecord -ActionLabel $ActionLabel
    $fullDetails = "{0}{1}{1}Recovery: {2}" -f $details, [Environment]::NewLine, $diagnostic.RecoveryHint

    Set-UiErrorState -Summary $diagnostic.UserMessage -Details $fullDetails
    Set-UiStatusMessage -Message $diagnostic.Title
    Set-SettingsFeedback -Message $diagnostic.UserMessage -Tone "error"

    if (-not $SuppressDialog) {
        [System.Windows.MessageBox]::Show(
            ("{0}`n`n{1}" -f $diagnostic.UserMessage, $diagnostic.RecoveryHint),
            $diagnostic.Title,
            "OK",
            "Error"
        ) | Out-Null
    }
}

function Get-AutoRefreshFailureMessage {
    param([int]$FailureCount)

    if ($FailureCount -le 1) {
        return (Get-LocalizedText "AutoRefreshTemporaryConflict")
    }

    Get-LocalizedText "AutoRefreshRepeatedFailure" $FailureCount
}

function Handle-AutoRefreshFailure {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $script:LastErrorRecord = $ErrorRecord
    $script:AutoRefreshFailureCount++
    $script:AutoRefreshLastFailureAt = Get-Date

    $failureMessage = Get-AutoRefreshFailureMessage -FailureCount $script:AutoRefreshFailureCount
    Set-UiStatusMessage -Message $failureMessage
    if ($script:AutoRefreshFailureCount -ge $script:AutoRefreshWarningThreshold) {
        Set-RefreshHealthVisual -Text (Get-LocalizedText "RefreshIssues" $script:AutoRefreshFailureCount) -Foreground "#FF8A5607" -Background "#FFFFFAF2" -BorderBrush "#FFF3DFC0" -SolidColor "#FFFF9500" -HaloColor "#22FF9500"
    }
    else {
        Set-RefreshHealthVisual -Text (Get-LocalizedText "RetryingRefresh") -Foreground "#FF8A5607" -Background "#FFFFFAF2" -BorderBrush "#FFF3DFC0" -SolidColor "#FFFF9500" -HaloColor "#22FF9500"
    }

    if ($script:AutoRefreshFailureCount -lt $script:AutoRefreshWarningThreshold) {
        Set-SettingsFeedback -Message $failureMessage -Tone "warning"
        return
    }

    $shouldShowDialog = $false
    if ($script:AutoRefreshFailureCount -ge $script:AutoRefreshDialogThreshold) {
        if (
            -not $script:AutoRefreshLastDialogAt -or
            (((Get-Date) - $script:AutoRefreshLastDialogAt).TotalSeconds -ge $script:AutoRefreshDialogCooldownSeconds)
        ) {
            $shouldShowDialog = $true
            $script:AutoRefreshLastDialogAt = Get-Date
        }
    }

    Show-UiDiagnosticError -ErrorRecord $ErrorRecord -ActionLabel "Auto refresh" -SuppressDialog:(-not $shouldShowDialog)
}

function Reset-AutoRefreshFailureState {
    $hadFailures = $script:AutoRefreshFailureCount -gt 0

    $script:AutoRefreshFailureCount = 0
    $script:AutoRefreshLastFailureAt = $null
    Set-RefreshHealthVisual -Text (Get-LocalizedText "RefreshHealthy") -Foreground "#FF216E3A" -Background "#FFF4FBF6" -BorderBrush "#FFD6ECDC" -SolidColor "#FF34C759" -HaloColor "#2234C759"

    if ($hadFailures) {
        Set-SettingsFeedback -Message (Get-LocalizedText "AutoRefreshRecovered") -Tone "success"
    }
}

function Clear-UiErrorState {
    Set-UiErrorState -Summary (Get-LocalizedText "NoErrorsYet") -Details (Get-LocalizedText "EverythingHealthy")
    $script:LastErrorRecord = $null
}

function Format-UiExceptionDetails {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$ActionLabel
    )

    $parts = @()
    if ($ActionLabel) { $parts += "Action: $ActionLabel" }
    $parts += "Time: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
    $parts += "Message: $($ErrorRecord.Exception.Message)"
    if ($ErrorRecord.CategoryInfo) { $parts += "Category: $($ErrorRecord.CategoryInfo)" }
    if ($ErrorRecord.FullyQualifiedErrorId) { $parts += "ErrorId: $($ErrorRecord.FullyQualifiedErrorId)" }
    if ($ErrorRecord.InvocationInfo -and $ErrorRecord.InvocationInfo.PositionMessage) {
        $parts += "Location: $($ErrorRecord.InvocationInfo.PositionMessage.Trim())"
    }
    if ($ErrorRecord.ScriptStackTrace) {
        $parts += "Stack:`n$($ErrorRecord.ScriptStackTrace.Trim())"
    }
    $parts -join [Environment]::NewLine
}

function Get-TrayModeLabel {
    switch ($script:TrayIconMode) {
        "monitor" { Get-LocalizedText "MonitorOnly" }
        "dashboard" { Get-LocalizedText "DashboardOnly" }
        default { Get-LocalizedText "CombinedStatus" }
    }
}

function Set-TrayMode {
    param(
        [ValidateSet("combined", "monitor", "dashboard")]
        [string]$Mode
    )

    $script:TrayIconMode = $Mode
    $script:SuppressTrayModeHandler = $true
    $controls.TrayModeCombinedMenuItem.IsChecked = ($Mode -eq "combined")
    $controls.TrayModeMonitorMenuItem.IsChecked = ($Mode -eq "monitor")
    $controls.TrayModeDashboardMenuItem.IsChecked = ($Mode -eq "dashboard")
    $script:SuppressTrayModeHandler = $false

    if ($script:TrayModeCombinedMenuItemTray) {
        $script:TrayModeCombinedMenuItemTray.Checked = ($Mode -eq "combined")
        $script:TrayModeMonitorMenuItemTray.Checked = ($Mode -eq "monitor")
        $script:TrayModeDashboardMenuItemTray.Checked = ($Mode -eq "dashboard")
    }

    $controls.MenuStatusModeItem.Header = "Tray mode: $(Get-TrayModeLabel)"
}

function Get-TrayIconForStatus {
    return Resolve-AppTrayIcon
}

function Update-TrayPresentation {
    if (-not $script:TrayIcon) { return }

    $tooltip = "Codex Monitor"
    if ($script:LastStatus) {
        switch ($script:TrayIconMode) {
            "monitor" { $tooltip = "Codex Monitor - Monitor {0}" -f $(if ($script:LastStatus.monitorState.running) { "On" } else { "Off" }) }
            "dashboard" { $tooltip = "Codex Monitor - Dashboard {0}" -f $(if ($script:LastStatus.dashboardState.running) { "On" } else { "Off" }) }
            default {
                $tooltip = "Codex Monitor - Monitor {0}, Dashboard {1}" -f `
                    $(if ($script:LastStatus.monitorState.running) { "On" } else { "Off" }), `
                    $(if ($script:LastStatus.dashboardState.running) { "On" } else { "Off" })
            }
        }
    }

    if ($tooltip.Length -gt 63) { $tooltip = $tooltip.Substring(0, 63) }
    $script:TrayIcon.Icon = Get-TrayIconForStatus
    $script:TrayIcon.Text = $tooltip
}

function Set-UiBusyState {
    param([bool]$Busy)

    $script:UiBusy = $Busy
    foreach ($button in $actionButtons) {
        $button.IsEnabled = -not $Busy
    }
    $controls.StartupMenuItem.IsEnabled = -not $Busy
    if ($script:TrayStartupMenuItem) {
        $script:TrayStartupMenuItem.Enabled = -not $Busy
    }
}

function Set-StatusIndicatorVisual {
    param(
        [object]$SolidIndicator,
        [object]$HaloIndicator,
        [string]$SolidColor,
        [string]$HaloColor
    )

    if ($SolidIndicator) {
        $SolidIndicator.Fill = New-StatusBrush $SolidColor
    }

    if ($HaloIndicator) {
        $HaloIndicator.Fill = New-StatusBrush $HaloColor
    }
}

Set-RefreshHealthVisual -Text "Refresh Checking"

function Update-UiButtonState {
    if ($script:UiBusy -or -not $script:LastStatus) { return }

    $monitorRunning = [bool]$script:LastStatus.monitorState.running
    $dashboardRunning = [bool]$script:LastStatus.dashboardState.running

    $controls.StartButton.IsEnabled = -not ($monitorRunning -and $dashboardRunning)
    $controls.StopButton.IsEnabled = ($monitorRunning -or $dashboardRunning)
    $controls.RestartButton.IsEnabled = ($monitorRunning -or $dashboardRunning)
    $controls.OpenButton.IsEnabled = $true
    $controls.TestButton.IsEnabled = $true
    $controls.RefreshButton.IsEnabled = $true
    $controls.ClearRebuildButton.IsEnabled = $true

    if ($monitorRunning -and $dashboardRunning) {
        $controls.ActionNotes.Text = Get-LocalizedText "ActionNotesRunning"
        $controls.HeaderStatus.Text = Get-LocalizedText "AllServicesAvailable"
        Set-StatusIndicatorVisual -SolidIndicator $controls.HeaderStatusEllipse -HaloIndicator $controls.HeaderStatusHalo -SolidColor "#FF34C759" -HaloColor "#2234C759"
        Set-MetaBadgeVisual -Text (Get-LocalizedText "Live") -Foreground "#FF216E3A" -Background "#FFF4FBF6" -BorderBrush "#FFD6ECDC"
    }
    elseif (-not $monitorRunning -and -not $dashboardRunning) {
        $controls.ActionNotes.Text = Get-LocalizedText "ActionNotesStopped"
        $controls.HeaderStatus.Text = Get-LocalizedText "AllServicesStopped"
        Set-StatusIndicatorVisual -SolidIndicator $controls.HeaderStatusEllipse -HaloIndicator $controls.HeaderStatusHalo -SolidColor "#FFFF3B30" -HaloColor "#22FF3B30"
        Set-MetaBadgeVisual -Text (Get-LocalizedText "Idle") -Foreground "#FF5B6776" -Background "#FFF6F8FB" -BorderBrush "#FFDCE4EC"
    }
    elseif ($monitorRunning) {
        $controls.ActionNotes.Text = Get-LocalizedText "ActionNotesMonitorOnly"
        $controls.HeaderStatus.Text = Get-LocalizedText "PartialServiceState"
        Set-StatusIndicatorVisual -SolidIndicator $controls.HeaderStatusEllipse -HaloIndicator $controls.HeaderStatusHalo -SolidColor "#FFFF9500" -HaloColor "#22FF9500"
        Set-MetaBadgeVisual -Text (Get-LocalizedText "MonitorOnly") -Foreground "#FF8A5607" -Background "#FFFFFAF2" -BorderBrush "#FFF3DFC0"
    }
    else {
        $controls.ActionNotes.Text = Get-LocalizedText "ActionNotesDashboardOnly"
        $controls.HeaderStatus.Text = Get-LocalizedText "PartialServiceState"
        Set-StatusIndicatorVisual -SolidIndicator $controls.HeaderStatusEllipse -HaloIndicator $controls.HeaderStatusHalo -SolidColor "#FFFF9500" -HaloColor "#22FF9500"
        Set-MetaBadgeVisual -Text (Get-LocalizedText "UiOnly") -Foreground "#FF8A5607" -Background "#FFFFFAF2" -BorderBrush "#FFF3DFC0"
    }

    if ($script:LastStatus.startup.installed) {
        $controls.StartupPreferenceValue.Text = Get-LocalizedText "Enabled"
        $controls.SettingsSummary.Text = Get-LocalizedText "SettingsSummaryOn" @((Get-TrayModeLabel))
    }
    else {
        $controls.StartupPreferenceValue.Text = Get-LocalizedText "Disabled"
        $controls.SettingsSummary.Text = Get-LocalizedText "SettingsSummaryOff" @((Get-TrayModeLabel))
    }

    $controls.TrayModePreferenceValue.Text = Get-TrayModeLabel
}

function Update-StartupMenuState {
    if (-not $script:LastStatus) { return }

    $script:SuppressStartupHandler = $true
    $controls.StartupMenuItem.IsChecked = [bool]$script:LastStatus.startup.installed
    $script:SuppressStartupHandler = $false

    if ($script:TrayStartupMenuItem) {
        $script:TrayStartupMenuItem.Checked = [bool]$script:LastStatus.startup.installed
        $script:TrayStartupMenuItem.Text = if ($script:LastStatus.startup.installed) { Get-LocalizedText "TrayLaunchOn" } else { Get-LocalizedText "TrayLaunchOff" }
    }
}

function Update-UiFromStatus {
    $script:CurrentPort = Resolve-CodexMonitorDashboardPort -Port $script:CurrentPort
    $status = Get-CodexMonitorStatusData -Port $script:CurrentPort -TailLines 24
    $snapshot = $status.snapshot
    $script:LastStatus = $status

    $controls.DashboardUrl.Text = $status.dashboardUrl
    $controls.MenuDashboardUrlItem.Header = Get-LocalizedText "DashboardMenuLabel" @($status.dashboardUrl)
    $controls.WatchingSummary.Text = Get-LocalizedText "CodexSessions"
    $controls.WatchingPath.Text = $status.config.sessionsRoot

    $controls.MonitorStatus.Text = if ($status.monitorState.running) { Get-LocalizedText "Running" } else { Get-LocalizedText "Stopped" }
    $controls.MonitorStatus.Foreground = New-StatusBrush $(if ($status.monitorState.running) { "#FF0F172A" } else { "#FF7F1D1D" })
    Set-StatusIndicatorVisual `
        -SolidIndicator $controls.MonitorIndicator `
        -HaloIndicator $controls.MonitorIndicatorHalo `
        -SolidColor $(if ($status.monitorState.running) { "#FF34C759" } else { "#FFFF3B30" }) `
        -HaloColor $(if ($status.monitorState.running) { "#2234C759" } else { "#22FF3B30" })
    $controls.MonitorPid.Text = if ($status.monitorState.pid) { "PID $($status.monitorState.pid)" } else { Get-LocalizedText "NoPidFile" }

    $controls.DashboardStatus.Text = if ($status.dashboardState.running) { Get-LocalizedText "Running" } else { Get-LocalizedText "Stopped" }
    $controls.DashboardStatus.Foreground = New-StatusBrush $(if ($status.dashboardState.running) { "#FF0F172A" } else { "#FF7F1D1D" })
    Set-StatusIndicatorVisual `
        -SolidIndicator $controls.DashboardIndicator `
        -HaloIndicator $controls.DashboardIndicatorHalo `
        -SolidColor $(if ($status.dashboardState.running) { "#FF34C759" } else { "#FFFF3B30" }) `
        -HaloColor $(if ($status.dashboardState.running) { "#2234C759" } else { "#22FF3B30" })
    $controls.DashboardPid.Text = if ($status.dashboardState.pid) { "PID $($status.dashboardState.pid)" } else { Get-LocalizedText "NoPidFile" }

    $controls.CompletedCount.Text = if ($snapshot) { [string]$snapshot.todayCompletedCount } else { "-" }
    $controls.NotifiedCount.Text = if ($snapshot) { [string]$snapshot.notifiedCount } else { "-" }
    $controls.LastTurn.Text = if ($snapshot -and $snapshot.lastNotifiedTurnId) { Get-LocalizedText "LastTurn" $snapshot.lastNotifiedTurnId } else { Get-LocalizedText "LastTurn" "-" }
    $controls.GeneratedAt.Text = if ($snapshot -and $snapshot.generatedAt) { Get-LocalizedText "Snapshot" $snapshot.generatedAt } else { Get-LocalizedText "Snapshot" "-" }
    $controls.Meta.Text = "Sessions root: $($status.config.sessionsRoot)`nLog file: $($status.config.logPath)`nDashboard port: $($script:CurrentPort)`nStartup task: $($status.startup.taskName)"
    $controls.Log.Text = if ($status.recentLog.Count -gt 0) { ($status.recentLog -join [Environment]::NewLine) } else { Get-LocalizedText "NoLogLinesYet" }
    $controls.Log.ScrollToEnd()

    if ($status.recentLog.Count -gt 0) {
        $latestLine = $status.recentLog[-1]
        $controls.LogSummary.Text = Get-LocalizedText "RecentLinesLatest" $status.recentLog.Count, $latestLine
    }
    else {
        $controls.LogSummary.Text = Get-LocalizedText "NoMonitorLinesYet"
    }

    if (-not $controls.BarkUrlTextBox.IsKeyboardFocused) {
        try {
            $controls.BarkUrlTextBox.Text = [string](Get-CodexBarkConfig).barkUrl
        }
        catch {
        }
    }

    if (-not $controls.DashboardPortTextBox.IsKeyboardFocused) {
        $controls.DashboardPortTextBox.Text = [string]$script:CurrentPort
    }

    Update-StartupMenuState
    Update-UiButtonState
    Update-TrayPresentation
}

function Set-ResponsiveLayout {
    $compact = $window.ActualWidth -lt 1080

    if ($compact) {
        $controls.MainContentGrid.ColumnDefinitions[0].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $controls.MainContentGrid.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(0)
        $controls.MainContentGrid.ColumnDefinitions[2].Width = [System.Windows.GridLength]::new(0)

        if ($controls.MainContentGrid.RowDefinitions.Count -lt 3) {
            $controls.MainContentGrid.RowDefinitions.Clear()
            $null = $controls.MainContentGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]@{ Height = [System.Windows.GridLength]::Auto })
            $null = $controls.MainContentGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]@{ Height = [System.Windows.GridLength]::new(18) })
            $null = $controls.MainContentGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]@{ Height = [System.Windows.GridLength]::Auto })
        }

        [System.Windows.Controls.Grid]::SetColumn($controls.ActionsPanel, 0)
        [System.Windows.Controls.Grid]::SetRow($controls.ActionsPanel, 0)
        [System.Windows.Controls.Grid]::SetColumn($controls.DetailsPanel, 0)
        [System.Windows.Controls.Grid]::SetRow($controls.DetailsPanel, 2)
    }
    else {
        $controls.MainContentGrid.RowDefinitions.Clear()
        $null = $controls.MainContentGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]@{ Height = [System.Windows.GridLength]::Auto })

        $controls.MainContentGrid.ColumnDefinitions[0].Width = [System.Windows.GridLength]::new(320)
        $controls.MainContentGrid.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(18)
        $controls.MainContentGrid.ColumnDefinitions[2].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)

        [System.Windows.Controls.Grid]::SetColumn($controls.ActionsPanel, 0)
        [System.Windows.Controls.Grid]::SetRow($controls.ActionsPanel, 0)
        [System.Windows.Controls.Grid]::SetColumn($controls.DetailsPanel, 2)
        [System.Windows.Controls.Grid]::SetRow($controls.DetailsPanel, 0)
    }
}

function Show-TrayBalloon {
    param(
        [string]$Title,
        [string]$Text,
        [System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info
    )

    if ($script:TrayIcon) {
        $script:TrayIcon.BalloonTipTitle = $Title
        $script:TrayIcon.BalloonTipText = $Text
        $script:TrayIcon.BalloonTipIcon = $Icon
        $script:TrayIcon.ShowBalloonTip(2500)
    }
}

function New-TrayContextMenu {
    $script:TrayMenu = [System.Windows.Forms.ContextMenuStrip]::new()
    $script:TrayShowMenuItem = $script:TrayMenu.Items.Add((Get-LocalizedText "TrayShow"))
    $script:TrayRefreshMenuItem = $script:TrayMenu.Items.Add((Get-LocalizedText "TrayRefresh"))
    $null = $script:TrayMenu.Items.Add("-")
    $script:TrayStartMenuItem = $script:TrayMenu.Items.Add((Get-LocalizedText "TrayStart"))
    $script:TrayStopMenuItem = $script:TrayMenu.Items.Add((Get-LocalizedText "TrayStop"))
    $script:TrayRestartMenuItem = $script:TrayMenu.Items.Add((Get-LocalizedText "TrayRestart"))
    $null = $script:TrayMenu.Items.Add("-")
    $script:TrayStartupMenuItem = [System.Windows.Forms.ToolStripMenuItem]::new((Get-LocalizedText "TrayLaunchOff"))
    $script:TrayStartupMenuItem.CheckOnClick = $false
    $null = $script:TrayMenu.Items.Add($script:TrayStartupMenuItem)
    $script:TrayModeMenuItem = [System.Windows.Forms.ToolStripMenuItem]::new((Get-LocalizedText "TrayIconModeTitle"))
    $script:TrayModeCombinedMenuItemTray = [System.Windows.Forms.ToolStripMenuItem]::new((Get-LocalizedText "CombinedStatus"))
    $script:TrayModeMonitorMenuItemTray = [System.Windows.Forms.ToolStripMenuItem]::new((Get-LocalizedText "MonitorOnly"))
    $script:TrayModeDashboardMenuItemTray = [System.Windows.Forms.ToolStripMenuItem]::new((Get-LocalizedText "DashboardOnly"))
    $script:TrayModeCombinedMenuItemTray.CheckOnClick = $true
    $script:TrayModeMonitorMenuItemTray.CheckOnClick = $true
    $script:TrayModeDashboardMenuItemTray.CheckOnClick = $true
    $null = $script:TrayModeMenuItem.DropDownItems.Add($script:TrayModeCombinedMenuItemTray)
    $null = $script:TrayModeMenuItem.DropDownItems.Add($script:TrayModeMonitorMenuItemTray)
    $null = $script:TrayModeMenuItem.DropDownItems.Add($script:TrayModeDashboardMenuItemTray)
    $null = $script:TrayMenu.Items.Add($script:TrayModeMenuItem)
    $null = $script:TrayMenu.Items.Add("-")
    $script:TrayExitMenuItem = $script:TrayMenu.Items.Add((Get-LocalizedText "TrayExit"))
}

function Register-TrayEventHandlers {
    $script:TrayShowMenuItem.Add_Click({ Show-MainWindow })
    $script:TrayRefreshMenuItem.Add_Click({
        try {
            Update-UiFromStatus
            Set-UiStatusMessage -Message (Get-LocalizedText "StatusRefreshedFromTray")
        }
        catch {
            Show-UiDiagnosticError -ErrorRecord $_ -ActionLabel (Get-LocalizedText "TrayRefreshAction")
        }
    })
    $script:TrayStartMenuItem.Add_Click({
        Invoke-UiAction -Label (Get-LocalizedText "StartMonitorDashboard") -Action {
            Start-CodexMonitorServices -Port $script:CurrentPort
        }
    })
    $script:TrayStopMenuItem.Add_Click({
        Invoke-UiAction -Label (Get-LocalizedText "StopMonitorDashboard") -Action {
            Stop-CodexMonitorServices
        }
    })
    $script:TrayRestartMenuItem.Add_Click({
        Invoke-UiAction -Label (Get-LocalizedText "RestartServices") -Action {
            Restart-CodexMonitorServices -Port $script:CurrentPort
        }
    })
    $script:TrayStartupMenuItem.Add_Click({
        if ($script:LastStatus -and $script:LastStatus.startup.installed) {
            Invoke-UiAction -Label (Get-LocalizedText "DisablingStartup") -Action {
                Uninstall-CodexMonitorStartup
            }
        }
        else {
            Invoke-UiAction -Label (Get-LocalizedText "EnablingStartup") -Action {
                Install-CodexMonitorStartup -IncludeDashboard -DashboardPort $script:CurrentPort
            }
        }
    })
    $script:TrayModeCombinedMenuItemTray.Add_Click({
        Set-TrayMode -Mode "combined"
        Update-TrayPresentation
        Update-UiButtonState
    })
    $script:TrayModeMonitorMenuItemTray.Add_Click({
        Set-TrayMode -Mode "monitor"
        Update-TrayPresentation
        Update-UiButtonState
    })
    $script:TrayModeDashboardMenuItemTray.Add_Click({
        Set-TrayMode -Mode "dashboard"
        Update-TrayPresentation
        Update-UiButtonState
    })
    $script:TrayExitMenuItem.Add_Click({
        $script:AllowExit = $true
        $window.Close()
    })
}

function Remove-TrayIconResources {
    if ($script:TrayIcon) {
        try { $script:TrayIcon.Visible = $false } catch {}
        try { $script:TrayIcon.Dispose() } catch {}
        $script:TrayIcon = $null
    }
    if ($script:TrayMenu) {
        try { $script:TrayMenu.Dispose() } catch {}
        $script:TrayMenu = $null
    }
}

function Initialize-TrayIcon {
    Remove-TrayIconResources
    New-TrayContextMenu

    $script:TrayIcon = [System.Windows.Forms.NotifyIcon]::new()
    $script:TrayIcon.Icon = Resolve-AppTrayIcon
    $script:TrayIcon.Text = "Codex Monitor"
    $script:TrayIcon.ContextMenuStrip = $script:TrayMenu
    Register-TrayEventHandlers
    $script:TrayIcon.Add_DoubleClick({ Show-MainWindow })
    $script:TrayIcon.Visible = $true
    Update-TrayPresentation
}

function Ensure-TrayIconReady {
    try {
        if (-not $script:TrayIcon -or -not $script:TrayMenu) {
            Initialize-TrayIcon
            return $true
        }

        $script:TrayIcon.Visible = $true
        if (-not $script:TrayIcon.Icon) {
            $script:TrayIcon.Icon = Resolve-AppTrayIcon
        }
        if (-not $script:TrayIcon.ContextMenuStrip) {
            $script:TrayIcon.ContextMenuStrip = $script:TrayMenu
        }
        return $true
    }
    catch {
        try {
            Initialize-TrayIcon
            Set-UiStatusMessage -Message (Get-LocalizedText "TrayRecovered")
            return $true
        }
        catch {
            return $false
        }
    }
}

function On-WindowMessage {
    param(
        [IntPtr]$Hwnd,
        [int]$Msg,
        [IntPtr]$WParam,
        [IntPtr]$LParam,
        [ref]$Handled
    )

    if ($Msg -eq [int]$script:TaskbarCreatedMessage) {
        try {
            Initialize-TrayIcon
            Update-StartupMenuState
            Update-TrayPresentation
            Set-UiStatusMessage -Message (Get-LocalizedText "TrayRecovered")
        }
        catch {
            Set-SettingsFeedback -Message (Get-LocalizedText "TrayUnavailableKeepWindow") -Tone "warning"
        }
    }

    return [IntPtr]::Zero
}

$script:WindowMessageHook = [System.Windows.Interop.HwndSourceHook]{
    param(
        [IntPtr]$Hwnd,
        [int]$Msg,
        [IntPtr]$WParam,
        [IntPtr]$LParam,
        [ref]$Handled
    )

    On-WindowMessage -Hwnd $Hwnd -Msg $Msg -WParam $WParam -LParam $LParam -Handled ([ref]$Handled.Value)
}

function Show-MainWindow {
    if ($script:TrayIcon) {
        try { $script:TrayIcon.Visible = $true } catch {}
    }
    $window.Show()
    $window.WindowState = [System.Windows.WindowState]::Normal
    $window.Activate() | Out-Null
    $window.Topmost = $true
    $window.Topmost = $false
}

function Hide-ToTray {
    param([string]$Reason = "Codex Monitor is still running in the tray.")

    if (-not (Ensure-TrayIconReady)) {
        Set-UiStatusMessage -Message (Get-LocalizedText "TrayUnavailableKeepWindow")
        Set-SettingsFeedback -Message (Get-LocalizedText "TrayUnavailableKeepWindow") -Tone "warning"
        return
    }

    $window.Hide()
    Set-UiStatusMessage -Message $Reason
    Show-TrayBalloon -Title "Codex Monitor" -Text $Reason
}

function Invoke-UiAction {
    param(
        [string]$Label,
        [scriptblock]$Action
    )

    try {
        Set-UiBusyState -Busy $true
        Set-UiStatusMessage -Message "$Label..."
        Set-SettingsFeedback -Message "$Label..." -Tone "progress"
        & $Action | Out-Null
        Update-UiFromStatus
        Set-UiStatusMessage -Message "$Label complete."
        Set-SettingsFeedback -Message "$Label complete." -Tone "success"
        Clear-UiErrorState
    }
    catch {
        $script:LastErrorRecord = $_
        Show-UiDiagnosticError -ErrorRecord $_ -ActionLabel $Label
    }
    finally {
        Set-UiBusyState -Busy $false
        Update-UiButtonState
    }
}

$controls.StartButton.Add_Click({
    Invoke-UiAction -Label (Get-LocalizedText "StartMonitorDashboard") -Action {
        Start-CodexMonitorServices -Port $script:CurrentPort
    }
})
$controls.StopButton.Add_Click({
    Invoke-UiAction -Label (Get-LocalizedText "StopMonitorDashboard") -Action {
        Stop-CodexMonitorServices
    }
})
$controls.RestartButton.Add_Click({
    Invoke-UiAction -Label (Get-LocalizedText "RestartServices") -Action {
        Restart-CodexMonitorServices -Port $script:CurrentPort
    }
})
$controls.OpenButton.Add_Click({
    Invoke-UiAction -Label (Get-LocalizedText "OpeningDashboard") -Action {
        Open-CodexMonitorDashboard -Port $script:CurrentPort
    }
})
$controls.TestButton.Add_Click({
    Invoke-UiAction -Label (Get-LocalizedText "SendingTestNotification") -Action {
        Invoke-CodexMonitorHealthCheck -Port $script:CurrentPort
    }
})
$controls.RefreshButton.Add_Click({
    Invoke-UiAction -Label (Get-LocalizedText "RefreshingStatus") -Action {
        $null = Get-CodexMonitorStatusData -Port $script:CurrentPort -TailLines 24
    }
})
$controls.CopyLogButton.Add_Click({
    Set-ClipboardText -Text $controls.Log.Text -SuccessMessage (Get-LocalizedText "RecentLogCopied")
})
    $controls.OpenLogButton.Add_Click({
        Invoke-UiAction -Label (Get-LocalizedText "OpeningLogFile") -Action {
            if (-not $script:LastStatus) {
                $null = Get-CodexMonitorStatusData -Port $script:CurrentPort -TailLines 24
            }
            Open-PathIfExists -Path $script:LastStatus.config.logPath -MissingMessage (Get-LocalizedText "MonitorLogMissing")
        }
    })
    $controls.ClearRebuildButton.Add_Click({
        Invoke-UiAction -Label (Get-LocalizedText "ClearingAndRebuilding") -Action {
            $result = Invoke-CodexMonitorCleanupAndRebuild -Port $script:CurrentPort
            if ($result -and $result.archivedCount -ge 0) {
                Set-SettingsFeedback -Message (Get-LocalizedText "CleanupRebuildCompleted" $result.archivedCount) -Tone "success"
            }
            else {
                Set-SettingsFeedback -Message (Get-LocalizedText "CleanupRebuildFallback") -Tone "success"
            }
        }
    })
$controls.CopyNotesButton.Add_Click({
    $notesText = "{0}{1}{1}{2}" -f $controls.ErrorSummary.Text, [Environment]::NewLine, $controls.ErrorDetails.Text
    Set-ClipboardText -Text $notesText -SuccessMessage (Get-LocalizedText "SystemNotesCopied")
})
$controls.OpenStateButton.Add_Click({
    Invoke-UiAction -Label (Get-LocalizedText "OpeningStateFile") -Action {
        if (-not $script:LastStatus) {
            $null = Get-CodexMonitorStatusData -Port $script:CurrentPort -TailLines 24
        }
        Open-PathIfExists -Path $script:LastStatus.config.statePath -MissingMessage (Get-LocalizedText "StateFileMissing")
    }
})
$controls.SaveSettingsButton.Add_Click({
    Invoke-UiAction -Label (Get-LocalizedText "SavingNotificationSettings") -Action {
        $barkUrl = $controls.BarkUrlTextBox.Text
        $portText = $controls.DashboardPortTextBox.Text
        $parsedPort = 0
        $previousPort = $script:CurrentPort

        if (-not [int]::TryParse($portText, [ref]$parsedPort)) {
            throw (Get-LocalizedText "DashboardPortInteger")
        }

        $savedSettings = Save-CodexMonitorAppSettings -BarkUrl $barkUrl -DashboardPort $parsedPort
        $script:CurrentPort = [int]$savedSettings.dashboardPort
        $controls.BarkUrlTextBox.Text = [string]$savedSettings.barkUrl
        $controls.DashboardPortTextBox.Text = [string]$savedSettings.dashboardPort

        if ($script:LastStatus -and $script:LastStatus.dashboardState.running -and $previousPort -ne $script:CurrentPort) {
            Set-UiStatusMessage -Message (Get-LocalizedText "SettingsSavedRestartRequired")
            Set-SettingsFeedback -Message (Get-LocalizedText "SettingsSavedRestartApply") -Tone "warning"
        }
        else {
            Set-SettingsFeedback -Message (Get-LocalizedText "NotificationSettingsSaved") -Tone "success"
        }
    }
})

$controls.MenuShowItem.Add_Click({ Show-MainWindow })
$controls.MenuOpenDashboardItem.Add_Click({
    Invoke-UiAction -Label (Get-LocalizedText "OpeningDashboard") -Action {
        Open-CodexMonitorDashboard -Port $script:CurrentPort
    }
})
$controls.MenuRefreshItem.Add_Click({
    Invoke-UiAction -Label (Get-LocalizedText "RefreshingStatus") -Action {
        $null = Get-CodexMonitorStatusData -Port $script:CurrentPort -TailLines 24
    }
})
$controls.LanguageEnglishMenuItem.Add_Click({
    if ($script:SuppressLanguageHandler) { return }
    Set-UiLanguage -Language "en-US"
})
$controls.LanguageChineseMenuItem.Add_Click({
    if ($script:SuppressLanguageHandler) { return }
    Set-UiLanguage -Language "zh-CN"
})
$controls.MenuTrayItem.Add_Click({
    Hide-ToTray -Reason (Get-LocalizedText "StillRunningInTray")
})
$controls.MenuExitItem.Add_Click({
    $script:AllowExit = $true
    $window.Close()
})

$controls.StartupMenuItem.Add_Click({
    if ($script:SuppressStartupHandler) { return }

    if ($controls.StartupMenuItem.IsChecked) {
        Invoke-UiAction -Label (Get-LocalizedText "EnablingStartup") -Action {
            Install-CodexMonitorStartup -IncludeDashboard -DashboardPort $script:CurrentPort
        }
    }
    else {
        Invoke-UiAction -Label (Get-LocalizedText "DisablingStartup") -Action {
            Uninstall-CodexMonitorStartup
        }
    }
})

$controls.TrayModeCombinedMenuItem.Add_Click({
    if ($script:SuppressTrayModeHandler) { return }
    Set-TrayMode -Mode "combined"
    Update-TrayPresentation
    Update-UiButtonState
})
$controls.TrayModeMonitorMenuItem.Add_Click({
    if ($script:SuppressTrayModeHandler) { return }
    Set-TrayMode -Mode "monitor"
    Update-TrayPresentation
    Update-UiButtonState
})
$controls.TrayModeDashboardMenuItem.Add_Click({
    if ($script:SuppressTrayModeHandler) { return }
    Set-TrayMode -Mode "dashboard"
    Update-TrayPresentation
    Update-UiButtonState
})

Initialize-TrayIcon

$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromSeconds($RefreshSeconds)
$timer.Add_Tick({
    if ($script:UiBusy) { return }

    try {
        Update-UiFromStatus
        Reset-AutoRefreshFailureState
        Set-UiStatusMessage -Message (Get-LocalizedText "AutoRefreshedAt" (Get-Date).ToString("HH:mm:ss"))
        Clear-UiErrorState
    }
    catch {
        Handle-AutoRefreshFailure -ErrorRecord $_
    }
})

$window.Add_SizeChanged({ Set-ResponsiveLayout })
$window.Add_StateChanged({
    if ($window.WindowState -eq [System.Windows.WindowState]::Minimized) {
        Set-UiStatusMessage -Message (Get-LocalizedText "MinimizedToTaskbar")
    }
})
$window.Add_Closing({
    param($sender, $eventArgs)
    if (-not $script:AllowExit) {
        $eventArgs.Cancel = $true
        Hide-ToTray -Reason (Get-LocalizedText "StillRunningInTray")
    }
})

$window.Add_SourceInitialized({
    $script:WindowSource = [System.Windows.Interop.HwndSource]::FromVisual($window)
    if ($script:WindowSource -and $script:TaskbarCreatedMessage -gt 0 -and $script:WindowMessageHook) {
        $script:WindowSource.AddHook($script:WindowMessageHook)
    }

    Apply-UiLanguage
    Ensure-TrayIconReady | Out-Null
    Set-TrayMode -Mode "combined"
    Set-ResponsiveLayout
    Sync-UiSettingsFields

    try {
        Update-UiFromStatus
        Clear-UiErrorState
        Set-UiStatusMessage -Message (Get-LocalizedText "Ready")
    }
    catch {
        Show-UiDiagnosticError -ErrorRecord $_ -ActionLabel (Get-LocalizedText "InitialLoad")
    }

    $timer.Start()
    Show-TrayBalloon -Title "Codex Monitor" -Text (Get-LocalizedText "DesktopGuiReady")
})

$window.Add_Closed({
    $timer.Stop()
    if ($script:WindowSource) {
        try {
            if ($script:WindowMessageHook) {
                $script:WindowSource.RemoveHook($script:WindowMessageHook)
            }
        } catch {}
        $script:WindowSource = $null
    }
    Remove-TrayIconResources
})

$window.ShowDialog() | Out-Null
