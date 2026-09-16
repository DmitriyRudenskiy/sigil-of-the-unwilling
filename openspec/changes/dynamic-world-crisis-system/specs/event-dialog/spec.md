# Specification: Event Dialog UI

## Overview
Интерфейс для отображения событий и выбора решений игроком. Должен быть атмосферным, понятным и блокирующим остальной интерфейс во время кризиса.

## Visual Design (Frostpunk-inspired)
- Темная полупрозрачная подложка с виньеткой
- Центральный контейнер с событием
- Стилизованные кнопки выборов с иконками последствий
- Анимация появления (fade-in + scale)
- Звуковые эффекты при открытии/выборе

## Scene Structure
```
EventDialog (Window/Control)
├── BackgroundOverlay (ColorRect with shader)
├── EventContainer (CenterContainer)
│   ├── EventHeader (HBoxContainer)
│   │   ├── EventIcon (TextureRect)
│   │   ├── EventTitle (Label)
│   │   └── CrisisBadge (Label, visible only for CRISIS type)
│   ├── EventDescription (RichTextLabel)
│   ├── ChoicesContainer (VBoxContainer)
│   │   ├── ChoiceButton_1 (Button)
│   │   │   ├── ChoiceText (Label)
│   │   │   ├── RequirementsLabel (Label, red if not met)
│   │   │   └── EffectsPreview (HBoxContainer)
│   │   │       ├── EffectIcon (TextureRect)
│   │   │       └── EffectValue (Label)
│   │   ├── ChoiceButton_2 (Button)
│   │   └── ChoiceButton_3 (Button)
│   └── TimerBar (ProgressBar, optional for timed events)
└── CloseButton (Button, disabled during crisis)
```

## Behavior

### Opening Dialog
1. Pause game logic (but not animations)
2. Block input to other UI elements
3. Play open animation
4. Highlight available choices
5. Show/hide requirements based on current state

### Choice Selection
1. On button press:
   - Validate requirements
   - If valid: highlight choice, show confirmation prompt
   - If invalid: shake animation, tooltip with reason
2. On confirm:
   - Play select animation
   - Call `EventManager.resolve_crisis()`
   - Show result summary (optional)
   - Close dialog

### Dynamic Content
- **Requirements**: Показывать красным если не выполнены
- **Effects Preview**: Иконки + значения изменений (+10 еды, -5 счастья)
- **Law Unlock**: Special badge if choice unlocks a law
- **Risk Indicator**: Шкала риска для вероятностных исходов

## Responsive Design
- Поддержка разрешений от 1280x720 до 4K
- Адаптивный размер шрифтов
- Перенос текста в описании
- Скролл для множества выборов (>4)

## Accessibility
- Поддержка клавиатуры (Enter для выбора, Esc для закрытия если не кризис)
- Colorblind-friendly иконки эффектов
- Tooltips с подробным описанием последствий

## Integration Code Example
```gdscript
# In EventDialog.gd
func show_event(event: Event):
    $EventContainer/EventTitle.text = event.title
    $EventContainer/EventDescription.text = event.description
    $EventContainer/EventIcon.texture = event.icon
    
    # Generate choice buttons
    for i in range(event.choices.size()):
        var choice = event.choices[i]
        var btn = $ChoicesContainer.get_child(i)
        btn.text = choice.text
        btn.disabled = not _check_requirements(choice.requirements)
        _update_effects_preview(btn, choice.effects)
    
    if event.type == Event.Type.CRISIS:
        $CloseButton.disabled = true
        CrisisManager.block_input()
    
    popup()
```

## Animation Specs
- **Open**: 0.3s fade-in + scale from 0.9 to 1.0
- **Close**: 0.2s fade-out
- **Choice Hover**: Slight scale up (1.05), glow effect
- **Invalid Choice**: Shake 3 times horizontally
- **Crisis Pulse**: Red border pulse every 2s

## Sound Design
- **Open**: Dramatic whoosh sound
- **Hover**: Subtle click
- **Select**: Confirm sound (different for crisis vs normal)
- **Invalid**: Error buzz
- **Close**: Soft close sound
