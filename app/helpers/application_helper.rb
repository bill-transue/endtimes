module ApplicationHelper
  THEME_STYLES = {
    "justice" => "bg-emerald-900/10 text-emerald-900 border-emerald-900/20",
    "hope" => "bg-sky-900/10 text-sky-950 border-sky-900/20",
    "sin" => "bg-rose-900/10 text-rose-950 border-rose-900/20",
    "prophecy" => "bg-violet-900/10 text-violet-950 border-violet-900/20",
    "mercy" => "bg-teal-900/10 text-teal-950 border-teal-900/20",
    "wisdom" => "bg-amber-900/10 text-amber-950 border-amber-900/20",
    "idolatry" => "bg-stone-900/10 text-stone-800 border-stone-900/20",
    "stretch" => "bg-amber-100 text-amber-950 border-amber-800/20"
  }.freeze

  def theme_chip(theme)
    key = theme.to_s.downcase
    css = THEME_STYLES[key] || "bg-stone-200 text-stone-800 border-stone-300"
    tag.span key, class: "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium tracking-wide #{css}"
  end

  def story_timestamp(story)
    time = story.published_at || story.created_at
    time&.in_time_zone&.strftime("%b %-d, %Y")
  end

  def flash_class(type)
    case type.to_s
    when "notice" then "border-emerald-800/30 bg-emerald-50 text-emerald-950"
    when "alert" then "border-rose-800/30 bg-rose-50 text-rose-950"
    else "border-stone-300 bg-white text-stone-800"
    end
  end

  def admin_filter_class(status)
    active = (status.to_s == params[:status].to_s) || (status.nil? && params[:status].blank?)
    base = "rounded-full border px-3 py-1"
    active ? "#{base} border-olive bg-olive text-parchment" : "#{base} border-olive/20 bg-white/70 text-olive hover:border-olive/40"
  end
end
